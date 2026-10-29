#!/usr/bin/env python3
"""Optional terminal presentation for the existing Make package target."""
import argparse
import collections
import contextlib
import os
import queue
import re
import signal
import subprocess
import sys
import threading
import time
from pathlib import Path

ANSI = re.compile(r'\x1b\[[0-?]*[ -/]*[@-~]')
CHILD = re.compile(r'^(?:Putting|Live) child (\S+) \((.+)\) PID (\d+)')
REMOVE = re.compile(r'^Removing child (\S+) PID (\d+) from chain')
LOSE = re.compile(r'^Reaping losing child (\S+) PID (\d+)')
FAIL = re.compile(r'^make(?:\[\d+\])?: \*\*\* \[(.+)\] (.+)')
DEBUG = re.compile(r'^(?:Using jobserver|Need a job token|Live child|Putting child|Obtained token|Reaping |Removing child|Released token|Acquired all)')
ERROR = re.compile(r'^(?:error(?:\[[^]]+\])?:|[\w.]*(?:Error|Exception):|.*?fatal error:|Unable to generate bindings:|\[download failed\]|curl:|gpg:.*\b(?:failed|BAD)\b|tar:.*(?:Error|EOF)|gzip:|.*?:\d+(?::\d+)?: (?:fatal )?error:|configure: error:|\[monitor error\])')
GO_NETWORK_ERROR = re.compile(r'^(?:go: .*|.*@\S+: .*?)(?:Get|Head|Post) "https?://[^"]+": .+')
PHASES = [('-setup', 'Preparing'), ('-stage', 'Staging'), ('-package', 'Packaging')]


def clean(text):
    return ''.join(c for c in ANSI.sub('', text) if c == '\t' or 32 <= ord(c) != 127)


def duration(seconds):
    minutes, seconds = divmod(int(seconds), 60)
    hours, minutes = divmod(minutes, 60)
    return f'{hours}h {minutes:02d}m' if hours else f'{minutes}m {seconds:02d}s'


class State:
    def __init__(self, projects):
        self.projects = set(projects)
        self.children = {}
        self.done = set()
        self.debs = set()
        self.failures = []
        self.diagnostics = collections.deque(maxlen=3)
        self.downloads = {}
        self.downloaded = set()
        self.cache_hits = set()
        self.started = time.monotonic()

    def consume(self, line):
        line = clean(line)
        notices = []
        if line.startswith('[build-deb] '):
            self.debs.add(line.removeprefix('[build-deb] ').strip())
        match = CHILD.match(line)
        if match:
            key, target, pid = match.groups()
            name = target
            for suffix, _ in PHASES:
                if target.endswith(suffix):
                    name = target[:-len(suffix)]
                    break
            if name in self.projects:
                child = self.children.setdefault((key, target), [target, time.monotonic(), False, pid])
                child[3] = pid
        match = LOSE.match(line)
        if match:
            for key, child in self.children.items():
                if key[0] == match[1] and child[3] == match[2]:
                    child[2] = True
                    self.downloads.pop(child[0], None)
        match = REMOVE.match(line)
        if match:
            key = next((key for key, child in self.children.items()
                        if key[0] == match[1] and child[3] == match[2]), None)
            child = self.children.pop(key, None)
            if child and not child[2]:
                target = child[0]
                self.downloads.pop(target, None)
                if target.endswith('-package') and target[:-8] in self.projects:
                    name = target[:-8]
                    if name not in self.done:
                        self.done.add(name)
                        notices.append(('success', f'{name} recipe packaged'))
        match = FAIL.match(line)
        if match:
            target = match[1].rsplit(': ', 1)[-1]
            name = target
            for suffix, _ in PHASES:
                if target.endswith(suffix):
                    name = target[:-len(suffix)]
                    break
            # Configure probes can run Make and fail without failing a recipe.
            # Only a selected recipe's failure belongs in the failure summary.
            if name in self.projects:
                self.failures.append(line)
                notices.append(('error', line))
            else:
                notices.append(('warning', 'Nested Make diagnostic: ' + line))
        diagnostic = None
        if GO_NETWORK_ERROR.match(line.strip()):
            diagnostic = 'Go network error: ' + line.strip()
        elif ERROR.match(line.strip()):
            # Interleaved output has no reliable target identity. Never attach it
            # to a failing target based on proximity or currently active jobs.
            diagnostic = line.strip()
        if diagnostic:
            if diagnostic not in self.diagnostics:
                self.diagnostics.append(diagnostic)
            notices.append(('error', 'Diagnostic (target unknown): ' + diagnostic))
        if line.startswith('Warning:') and ('retry' in line.lower() or 'retries' in line.lower()):
            notices.append(('warning', line))
        match = re.match(r'^\[build-download\] (start|end|failed|cached) (\S+)(?: (.*))?$', line)
        if match:
            if match[1] == 'start':
                self.downloads[match[2]] = (match[3] or '', time.monotonic())
            elif match[1] == 'cached':
                self.cache_hits.add((match[3] or '').strip())
            else:
                download = self.downloads.pop(match[2], None)
                if download and match[1] == 'end':
                    self.downloaded.add(download[0].strip())
                    name = match[2].removesuffix('-setup')
                    notices.append(('download', f'{name} downloaded {download[0].rsplit("/", 1)[-1]}'))
        return notices

    def rows(self):
        rows = {}
        for target, started, failed, pid in self.children.values():
            if failed:
                continue
            name, phase = target, 'Building'
            for suffix, label in PHASES:
                if target.endswith(suffix):
                    name, phase = target[:-len(suffix)], label
                    break
            if name not in self.projects:
                continue
            detail = ''
            if target in self.downloads:
                phase = 'Downloading'
                detail = self.downloads[target][0].rsplit('/', 1)[-1]
            rows[target] = (name, phase, time.monotonic() - started, detail)
        # Download events are authoritative even before Make's child event arrives.
        for target, (url, started) in self.downloads.items():
            name = target.removesuffix('-setup')
            if name in self.projects:
                rows[target] = (name, 'Downloading', time.monotonic() - started, url.rsplit('/', 1)[-1])
        return sorted(rows.values(), key=lambda row: (row[1] != 'Downloading', row[0], row[1]))


class Display:
    """Rich Live uses the normal screen, preserving scrollback and event history."""
    def __init__(self, state, cached, log, enabled):
        self.state, self.cached, self.log = state, cached, log
        self.console = self.live = None
        self.pending = []
        if enabled:
            try:
                from rich.console import Console, Group
                from rich.live import Live
                from rich.table import Table
                from rich.text import Text
                from rich.spinner import Spinner
                from rich.padding import Padding
            except ImportError:
                raise RuntimeError('Rich is required for the interface. Install python3-rich on Ubuntu, or use --plain.')
            self.console = Console(highlight=False)
            self.Group, self.Table, self.Text, self.Padding = Group, Table, Text, Padding
            self.spinner = Spinner('dots', style='bright_cyan')
            self.live = Live(console=self.console, screen=False, transient=True,
                             auto_refresh=False, redirect_stdout=False, redirect_stderr=False)

    def start(self):
        if not self.console:
            return
        self.console.print()
        self.console.print('  OwnGoal Stripe', style='bold bright_white')
        self.console.print('  Build workspace', style='dim')
        self.console.print()
        self.console.print(f'  {len(self.state.projects)} recipes selected    {self.cached} with existing build cache', style='dim')
        self.console.print(self.Text('  Log  ' + str(self.log), style='dim'))
        self.console.print()
        self.live.start()

    def notice(self, kind, message):
        if not self.console:
            return
        colors = {'success': 'green', 'error': 'bold red', 'warning': 'yellow', 'download': 'cyan'}
        text = self.Text('  ' + duration(time.monotonic() - self.state.started) + '  ', style='dim')
        text.append(message, style=colors[kind])
        self.pending.append(text)

    def refresh(self):
        if not self.console:
            return
        state = self.state
        rows = state.rows()
        heading = self.Table.grid(padding=(0, 2))
        heading.add_row(self.spinner,
                        self.Text('Building packages' if not state.failures else 'Waiting for active tasks to finish', style='bold'),
                        self.Text(duration(time.monotonic() - state.started), style='dim'))
        packaging = self.Text('Packaging  ', style='bold')
        packaging.append(f'{len(state.done)}/{len(state.projects)} recipes completed    {len(state.debs)} DEBs produced', style='bright_white')
        packaging.append('  (this run)', style='dim')
        sources = self.Text('Sources    ', style='bold')
        sources.append(f'{len(state.downloaded)} downloaded    {len(state.cache_hits)} cached files used', style='dim')
        downloading = sum(row[1] == 'Downloading' for row in rows)
        active = self.Text(f'Active tasks ({len(rows)})', style='bold')
        if downloading:
            active.append(f'    {downloading} downloading', style='cyan')
        before = [heading, self.Text(''), packaging, sources, self.Text(''), active]

        after = []
        if state.failures:
            failures = list(dict.fromkeys(state.failures))
            top_level = [line for line in failures if line.startswith('make:')]
            after.extend([self.Text(''), self.Text('Failed targets' if top_level else 'Nested Make failures', style='bold red')])
            for line in (top_level or failures)[-3:]:
                match = FAIL.match(line)
                location, separator, target = match[1].rpartition(': ')
                text = self.Text('  ' + (target if separator else match[1]) + '  ' + match[2], style='red')
                if separator:
                    text.append('  (' + location + ')', style='dim')
                after.append(text)
        if state.diagnostics:
            after.extend([self.Text(''), self.Text('Recent diagnostics — target unknown', style='bold yellow')])
            after.extend(self.Text('  ' + line, style='yellow', overflow='ellipsis', no_wrap=True)
                         for line in state.diagnostics)
        after.extend([self.Text(''), self.Text('Ctrl+C to stop safely. Run the same command to resume.', style='dim')])

        # Reserve space for section headings, wrapping and the overflow count.
        fixed = self.Padding(self.Group(*before, self.Text(''), *after), (1, 2))
        fixed_height = len(self.console.render_lines(fixed))
        limit = max(1, min(8, self.console.height - fixed_height - 1))
        table = self.Table.grid(padding=(0, 2))
        table.width = min(100, self.console.width - 4)
        table.add_column(ratio=2, overflow='ellipsis', no_wrap=True)
        table.add_column(width=12, no_wrap=True)
        table.add_column(ratio=2, overflow='ellipsis', no_wrap=True)
        table.add_column(width=9, justify='right', no_wrap=True)
        colors = {'Downloading': 'cyan', 'Preparing': 'blue', 'Building': 'bright_white', 'Staging': 'blue', 'Packaging': 'magenta'}
        for name, phase, elapsed, filename in rows[:limit]:
            table.add_row(self.Text(name, style='bold'), self.Text(phase, style=colors[phase]),
                          self.Text(filename, style='dim'), self.Text(duration(elapsed), style='dim'))
        if not rows:
            table.add_row(self.Text('No active tasks.' if state.failures else 'Resolving dependencies...', style='dim'), '', '', '')
        overflow = [self.Text(f'  {len(rows) - limit} more active targets', style='dim')] if len(rows) > limit else []
        self.live.update(self.Padding(self.Group(*before, table, *overflow, *after), (1, 2)), refresh=False)
        # Batch persistent events and the live frame into one terminal update.
        stream = self.console.file
        stream.write('\x1b[?2026h')
        try:
            if self.pending:
                self.console.print(self.Group(*self.pending))
                self.pending.clear()
            else:
                self.live.refresh()
        finally:
            stream.write('\x1b[?2026l')
            stream.flush()

    def stop(self):
        if self.live:
            if self.pending:
                self.refresh()
            self.live.stop()

    def finish(self, code, interrupted):
        outcome = 'Interrupted' if interrupted else 'Build complete' if code == 0 else 'Build failed'
        def emit(message='', style=None):
            if self.console:
                self.console.print(self.Text('  ' + message if message else '', style=style))
            else:
                print('  ' + message if message else '')

        emit()
        emit(outcome, 'bold green' if code == 0 else 'bold red')
        emit(f'Exit code: {code}', 'dim')

        emit()
        emit('Packaging — this run', 'bold')
        emit(f'  Recipes completed: {len(self.state.done)} / {len(self.state.projects)}')
        emit(f'  DEBs produced:     {len(self.state.debs)}')

        emit()
        emit('Sources — this run', 'bold')
        emit(f'  Downloaded:        {len(self.state.downloaded)}')
        emit(f'  Cached files used: {len(self.state.cache_hits)}')

        # Top-level failures identify recipes; nested Make failures usually
        # repeat the same failure as it propagates. Keep those in the full log.
        failures = list(dict.fromkeys(self.state.failures))
        top_level = [line for line in failures if line.startswith('make:')]
        if failures:
            emit()
            emit('Failed targets' if top_level else 'Nested Make failures', 'bold red')
            for line in top_level or failures[-3:]:
                match = FAIL.match(line)
                location, separator, target = match[1].rpartition(': ')
                emit(f'  {target if separator else match[1]} ({match[2]})', 'red')
                if separator:
                    emit('    ' + location, 'dim')

        if self.state.diagnostics:
            emit()
            emit('Recent diagnostics', 'bold yellow')
            emit('Target unknown; these lines are not assigned to the targets above.', 'dim')
            for line in self.state.diagnostics:
                emit('  ' + line, 'yellow')

        emit()
        emit('Full log', 'bold')
        emit('  ' + str(self.log), 'dim')
        emit()


def run(command, projects, work, log, interactive):
    state = State(projects)
    cached = sum((work / p / '.build_complete').exists() for p in projects)
    display = Display(state, cached, log, interactive)
    log.parent.mkdir(parents=True, exist_ok=True)
    events = queue.Queue()
    # A separate process group allows signals to reach the entire build tree.
    proc = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                            start_new_session=True)
    interrupted = False

    def forward(sig, frame):
        nonlocal interrupted
        interrupted = True
        if proc.poll() is None:
            with contextlib.suppress(ProcessLookupError):
                os.killpg(proc.pid, sig)

    previous = {sig: signal.signal(sig, forward) for sig in (signal.SIGINT, signal.SIGTERM)}

    def read_output():
        try:
            with log.open('ab') as output:
                output.write(('\n=== Build started ' + time.strftime('%Y-%m-%d %H:%M:%S') + ' ===\n').encode())
                while True:
                    raw = proc.stdout.readline()
                    if not raw:
                        break
                    output.write(raw)
                    output.flush()
                    events.put(raw.decode('utf-8', errors='replace'))
        except Exception as exc:
            events.put('[monitor error] ' + str(exc) + '\n')
            with contextlib.suppress(ProcessLookupError):
                os.killpg(proc.pid, signal.SIGTERM)
        finally:
            events.put(None)

    reader = threading.Thread(target=read_output, daemon=True)
    reader.start()
    eof, last_draw = False, 0
    try:
        display.start()
        while not eof:
            try:
                item = events.get(timeout=0.1)
                if item is None:
                    eof = True
                else:
                    for line in item.splitlines():
                        for kind, message in state.consume(line):
                            display.notice(kind, message)
                    if not interactive and not DEBUG.match(item) and not item.startswith(('[build-download]', '[build-deb]')):
                        sys.stdout.write(item)
                        sys.stdout.flush()
            except queue.Empty:
                pass
            if time.monotonic() - last_draw >= 0.5:
                display.refresh()
                last_draw = time.monotonic()
        code = proc.wait()
        reader.join()
    except BaseException:
        with contextlib.suppress(ProcessLookupError):
            os.killpg(proc.pid, signal.SIGTERM)
        proc.wait()
        raise
    finally:
        display.stop()
        for sig, handler in previous.items():
            signal.signal(sig, handler)
    display.finish(code, interrupted)
    return 128 - code if code < 0 else code


def main():
    parser = argparse.ArgumentParser(description=__doc__, epilog='Example: python3 build_tools/build_status.py package "SUBPROJECTS=$packages"')
    parser.add_argument('--plain', action='store_true', help='Print ordinary build output without Rich')
    parser.add_argument('--log', type=Path, help='Append full output to this file')
    parser.add_argument('--make', default='make', help='GNU Make executable')
    parser.add_argument('make_args', nargs='*', help='Optional package goal and Make variable assignments')
    args = parser.parse_args()
    variables = [arg for arg in args.make_args if arg != 'package']
    if any('=' not in arg or arg.startswith('-') for arg in variables):
        parser.error('Use the package goal and Make variable assignments only; set CORE_COUNT for concurrency.')
    # Query the same Makefile and overrides; never infer the selected recipes.
    query = subprocess.run([args.make, '-s', '-j1', *variables, 'MEMO_QUIET=1',
                            'print-SUBPROJECTS', 'print-BUILD_WORK', 'print-BUILD_ROOT'],
                           stdout=subprocess.PIPE, text=True)
    if query.returncode:
        return query.returncode
    values = query.stdout.strip().splitlines()
    if len(values) != 3:
        raise RuntimeError('Unexpected Make metadata output; no build was started.')
    projects, work, root = values
    log = args.log or Path(root) / 'build_work' / 'build-ui.log'
    interactive = not args.plain and sys.stdout.isatty() and os.environ.get('TERM') != 'dumb'
    command = [args.make, *variables, 'BUILD_STATUS_EVENTS=1', '--debug=j', '--output-sync=none', 'package']
    return run(command, projects.split(), Path(work), log, interactive)


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (OSError, RuntimeError) as exc:
        print('Build interface: ' + str(exc), file=sys.stderr)
        sys.exit(1)
