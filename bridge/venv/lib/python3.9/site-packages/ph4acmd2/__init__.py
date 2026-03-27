#!/usr/bin/env python3
# -*- coding: utf-8 -*-

# Some sources inspired by:
# Copyright (c) 2016-present Valentin Kazakov
#
# This module is part of asyncpg and is released under
# the Apache 2.0 License: http://www.apache.org/licenses/LICENSE-2.0
#
# This lib is inspired by Cmd standard lib Python >3.5 (under Python Software
# Foundation License 2)

import asyncio
import logging
import os
import sys
import threading
from contextlib import suppress
from typing import Optional

import cmd2

logger = logging.getLogger(__name__)


class Cmd(cmd2.Cmd):
    prompt = "$> "

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)

        self.run_loop = False
        self.loop = None
        self.rmode = "Reader"
        self.cmd_running = True
        self.reader_enabled = True
        self.is_win = False

    def _start_controller(self):
        """
        Control structure to start new cmd
        """
        # Loop check
        if sys.platform == "win32":
            self.is_win = True

        if self.loop is None:
            if self.is_win:
                self.loop = asyncio.ProactorEventLoop()
                asyncio.set_event_loop(self.loop)
                logger.debug("Starting new ProactorEventLoop")
            else:
                self.loop = asyncio.get_event_loop()
                logger.debug("Starting new event loop")

        # Starting by adding "tasks" to the "loop"
        if self.rmode == "Reader":
            self._start_reader()
        elif self.rmode == "Run":
            self._start_run()
        else:
            raise TypeError("self.mode is not Reader or Run.")

        # Start or not loop.run_forever
        if self.run_loop:
            try:
                print("Cmd._start_controller start loop inside Cmd object!")
                self.stdout.flush()
                self.loop.run_forever()
            except KeyboardInterrupt:
                print("Cmd._start_controller stop loop. Bye.")
                self.loop.stop()
                pending = asyncio.all_tasks(loop=self.loop)
                print(pending)
                for task in pending:
                    task.cancel()
                    with suppress(asyncio.CancelledError):
                        self.loop.run_until_complete(task)
                # self.loop.close()

    def _start_run(self):
        if self.loop is None:
            raise TypeError("self.loop is None.")
        self.loop.create_task(self._read_line())
        self.loop.create_task(self._greeting())
        logger.debug("start_run kicked of reading tasks")

    def _start_reader(self):
        self.reset_reader()
        self.loop.create_task(self._greeting())

    def reset_reader(self):
        if self.loop is None:
            raise TypeError("self.loop is None.")

        self.reader_enabled = True  # Ensure reading is enabled
        if not self.is_win:
            self.loop.add_reader(self.stdin.fileno(), self.reader)
        else:
            self.loop.create_task(self._read_line())

    def remove_reader(self):
        if self.loop is None:
            raise TypeError("self.loop is None.")
        self.reader_enabled = False  # Disable reading

        if not self.is_win:
            self.loop.remove_reader(self.stdin.fileno())

    def switch_reader(self, enable=True):
        self.reader_enabled = enable

    def reader(self):
        if not self.reader_enabled:
            return
        line = sys.stdin.readline()
        self._exec_cmd(line)
        sys.stdout.write(self.prompt)
        sys.stdout.flush()

    async def _read_line(self):
        while True:
            if self.reader_enabled:
                # Run stdin reading in a separate thread using run_in_executor
                line = await self.loop.run_in_executor(None, sys.stdin.readline)
                self._exec_cmd(line)
                sys.stdout.write(self.prompt)
                sys.stdout.flush()
            else:
                await asyncio.sleep(1)  # Sleep briefly to avoid a tight loop

    async def _greeting(self):
        sys.stdout.write(self.prompt)
        sys.stdout.flush()

    def _exec_cmd(self, line):
        r = self.onecmd_plus_hooks(line)
        self.cmd_running = not r
        return r

    async def acmdloop(self, intro: Optional[str] = None) -> int:
        """cmdloop() from cmd2.py"""
        # cmdloop() expects to be run in the main thread to support extensive use of KeyboardInterrupts throughout the
        # other built-in functions. You are free to override cmdloop, but much of cmd2's features will be limited.
        if not threading.current_thread() is threading.main_thread():
            raise RuntimeError("cmdloop must be run in the main thread")

        # Register a SIGINT signal handler for Ctrl+C
        import signal

        original_sigint_handler = signal.getsignal(signal.SIGINT)
        signal.signal(signal.SIGINT, self.sigint_handler)

        # Grab terminal lock before the command line prompt has been drawn by readline
        self.terminal_lock.acquire()

        # Always run the preloop first
        for func in self._preloop_hooks:
            func()
        self.preloop()

        # If transcript-based regression testing was requested, then do that instead of the main loop
        if self._transcript_files is not None:
            self._run_transcript_tests([os.path.expanduser(tf) for tf in self._transcript_files])
        else:
            # If an intro was supplied in the method call, allow it to override the default
            if intro is not None:
                self.intro = intro

            # Print the intro, if there is one, right after the preloop
            if self.intro is not None:
                self.poutput(self.intro)

            # And then call _cmdloop() to enter the main loop
            await self._acmdloop()

        # Run the postloop() no matter what
        for func in self._postloop_hooks:
            func()
        self.postloop()

        # Release terminal lock now that postloop code should have stopped any terminal updater threads
        # This will also zero the lock count in case cmdloop() is called again
        self.terminal_lock.release()

        # Restore the original signal handler
        signal.signal(signal.SIGINT, original_sigint_handler)

        return self.exit_code

    async def _acmdloop(self) -> None:
        """From: cmd2.py"""
        saved_readline_settings = None

        try:
            # Get sigint protection while we set up readline for cmd2
            with self.sigint_protection:
                saved_readline_settings = self._set_up_cmd2_readline()

            # Run startup commands
            stop = self.runcmds_plus_hooks(self._startup_commands)  # type: ignore[arg-type]
            self._startup_commands.clear()
            self._start_controller()

            while not stop and self.cmd_running:
                # Get commands from user
                try:
                    await asyncio.sleep(1)
                    # line = self._pseudo_raw_input(self.prompt)
                except KeyboardInterrupt as ex:
                    if self.quit_on_sigint:
                        raise ex
                    else:
                        self.poutput("^C")

                # Run the command along with all associated pre and post hooks
                # stop = self.onecmd_plus_hooks(line)

        finally:
            # Get sigint protection while we restore readline settings
            with self.sigint_protection:
                if saved_readline_settings is not None:
                    self._restore_readline(saved_readline_settings)
