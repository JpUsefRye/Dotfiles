python

# GDB dashboard - Modular visual interface for GDB in Python.
#
# https://github.com/cyrus-and/gdb-dashboard

import ast
import fcntl
import os
import re
import struct
import termios
import traceback
import math

# Common attributes ------------------------------------------------------------

class R():

    @staticmethod
    def attributes():
        return {
            # miscellaneous
            'ansi': {
                'doc': 'Control the ANSI output of the dashboard.',
                'default': True,
                'type': bool
            },
            'syntax_highlighting': {
                'doc': """Pygments style to use for syntax highlighting.
Using an empty string (or a name not in the list) disables this feature.
The list of all the available styles can be obtained with (from GDB itself):

    python from pygments.styles import get_all_styles as styles
    python for s in styles(): print(s)
""",
                'default': 'vim',
                'type': str
            },
            # prompt
            'prompt': {
                'doc': """Command prompt.
This value is parsed as a Python format string in which `{status}` is expanded
with the substitution of either `prompt_running` or `prompt_not_running`
attributes, according to the target program status. The resulting string must be
a valid GDB prompt, see the command `python print(gdb.prompt.prompt_help())`""",
                'default': '{status}'
            },
            'prompt_running': {
                'doc': """`{status}` when the target program is running.
See the `prompt` attribute. This value is parsed as a Python format string in
which `{pid}` is expanded with the process identifier of the target program.""",
                'default': '\[\e[1;35m\]>>>\[\e[0m\]'
            },
            'prompt_not_running': {
                'doc': '`{status}` when the target program is not running.',
                'default': '\[\e[1;30m\]>>>\[\e[0m\]'
            },
            # divider
            'divider_fill_char_primary': {
                'doc': 'Filler around the label for primary dividers',
                'default': '─'
            },
            'divider_fill_char_secondary': {
                'doc': 'Filler around the label for secondary dividers',
                'default': '─'
            },
            'divider_fill_style_primary': {
                'doc': 'Style for `divider_fill_char_primary`',
                'default': '36'
            },
            'divider_fill_style_secondary': {
                'doc': 'Style for `divider_fill_char_secondary`',
                'default': '1;30'
            },
            'divider_label_style_on_primary': {
                'doc': 'Label style for non-empty primary dividers',
                'default': '1;33'
            },
            'divider_label_style_on_secondary': {
                'doc': 'Label style for non-empty secondary dividers',
                'default': '0'
            },
            'divider_label_style_off_primary': {
                'doc': 'Label style for empty primary dividers',
                'default': '33'
            },
            'divider_label_style_off_secondary': {
                'doc': 'Label style for empty secondary dividers',
                'default': '1;30'
            },
            'divider_label_skip': {
                'doc': 'Gap between the aligning border and the label.',
                'default': 3,
                'type': int,
                'check': check_ge_zero
            },
            'divider_label_margin': {
                'doc': 'Number of spaces around the label.',
                'default': 1,
                'type': int,
                'check': check_ge_zero
            },
            'divider_label_align_right': {
                'doc': 'Label alignment flag.',
                'default': False,
                'type': bool
            },
            # common styles
            'style_selected_1': {
                'default': '1;32'
            },
            'style_selected_2': {
                'default': '32'
            },
            'style_low': {
                'default': '1;30'
            },
            'style_high': {
                'default': '1;37'
            },
            'style_error': {
                'default': '31'
            }
        }

# Common -----------------------------------------------------------------------

def run(command):
    return gdb.execute(command, to_string=True)

def ansi(string, style):
    if R.ansi:
        return '\x1b[{}m{}\x1b[0m'.format(style, string)
    else:
        return string

def divider(width, label='', primary=False, active=True):
    if primary:
        divider_fill_style = R.divider_fill_style_primary
        divider_fill_char = R.divider_fill_char_primary
        divider_label_style_on = R.divider_label_style_on_primary
        divider_label_style_off = R.divider_label_style_off_primary
    else:
        divider_fill_style = R.divider_fill_style_secondary
        divider_fill_char = R.divider_fill_char_secondary
        divider_label_style_on = R.divider_label_style_on_secondary
        divider_label_style_off = R.divider_label_style_off_secondary
    if label:
        if active:
            divider_label_style = divider_label_style_on
        else:
            divider_label_style = divider_label_style_off
        skip = R.divider_label_skip
        margin = R.divider_label_margin
        before = ansi(divider_fill_char * skip, divider_fill_style)
        middle = ansi(label, divider_label_style)
        after_length = width - len(label) - skip - 2 * margin
        after = ansi(divider_fill_char * after_length, divider_fill_style)
        if R.divider_label_align_right:
            before, after = after, before
        return ''.join([before, ' ' * margin, middle, ' ' * margin, after])
    else:
        return ansi(divider_fill_char * width, divider_fill_style)

def check_gt_zero(x):
    return x > 0

def check_ge_zero(x):
    return x >= 0

def to_unsigned(value, size=8):
    # values from GDB can be used transparently but are not suitable for
    # being printed as unsigned integers, so a conversion is needed
    mask = (2 ** (size * 8)) - 1
    return int(value.cast(gdb.Value(mask).type)) & mask

def to_string(value):
    # attempt to convert an inferior value to string; OK when (Python 3 ||
    # simple ASCII); otherwise (Python 2.7 && not ASCII) encode the string as
    # utf8
    try:
        value_string = str(value)
    except UnicodeEncodeError:
        value_string = unicode(value).encode('utf8')
    return value_string

def format_address(address):
    pointer_size = gdb.parse_and_eval('$pc').type.sizeof
    return ('0x{{:0{}x}}').format(pointer_size * 2).format(address)

class Beautifier():
    def __init__(self, filename, tab_size=4):
        self.tab_spaces = ' ' * tab_size
        self.active = False
        if not R.ansi:
            return
        # attempt to set up Pygments
        try:
            import pygments.lexers
            import pygments.formatters
            formatter_class = pygments.formatters.Terminal256Formatter
            self.formatter = formatter_class(style=R.syntax_highlighting)
            self.lexer = pygments.lexers.get_lexer_for_filename(filename)
            self.active = True
        except ImportError:
            # Pygments not available
            pass
        except pygments.util.ClassNotFound:
            # no lexer for this file or invalid style
            pass

    def process(self, source):
        # convert tabs anyway
        source = source.replace('\t', self.tab_spaces)
        if self.active:
            import pygments
            source = pygments.highlight(source, self.lexer, self.formatter)
        return source.rstrip('\n')

# Dashboard --------------------------------------------------------------------

class Dashboard(gdb.Command):
    """Redisplay the dashboard."""

    def __init__(self):
        gdb.Command.__init__(self, 'dashboard',
                             gdb.COMMAND_USER, gdb.COMPLETE_NONE, True)
        self.output = None  # main terminal
        # setup subcommands
        Dashboard.ConfigurationCommand(self)
        Dashboard.OutputCommand(self)
        Dashboard.EnabledCommand(self)
        Dashboard.LayoutCommand(self)
        # setup style commands
        Dashboard.StyleCommand(self, 'dashboard', R, R.attributes())
        # disabled by default
        self.enabled = None
        self.disable()

    def on_continue(self, _):
        # try to contain the GDB messages in a specified area unless the
        # dashboard is printed to a separate file (dashboard -output ...)
        if self.is_running() and not self.output:
            width = Dashboard.get_term_width()
            gdb.write(Dashboard.clear_screen())
            gdb.write(divider(width, 'Output/messages', True))
            gdb.write('\n')
            gdb.flush()

    def on_stop(self, _):
        if self.is_running():
            self.render(clear_screen=False)

    def on_exit(self, _):
        if not self.is_running():
            return
        # collect all the outputs
        outputs = set()
        outputs.add(self.output)
        outputs.update(module.output for module in self.modules)
        outputs.remove(None)
        # clean the screen and notify to avoid confusion
        for output in outputs:
            try:
                with open(output, 'w') as fs:
                    fs.write(Dashboard.reset_terminal())
                    fs.write(Dashboard.clear_screen())
                    fs.write('--- EXITED ---')
            except:
                # skip cleanup for invalid outputs
                pass

    def enable(self):
        if self.enabled:
            return
        self.enabled = True
        # setup events
        gdb.events.cont.connect(self.on_continue)
        gdb.events.stop.connect(self.on_stop)
        gdb.events.exited.connect(self.on_exit)

    def disable(self):
        if not self.enabled:
            return
        self.enabled = False
        # setup events
        gdb.events.cont.disconnect(self.on_continue)
        gdb.events.stop.disconnect(self.on_stop)
        gdb.events.exited.disconnect(self.on_exit)

    def load_modules(self, modules):
        self.modules = []
        for module in modules:
            info = Dashboard.ModuleInfo(self, module)
            self.modules.append(info)

    def redisplay(self, style_changed=False):
        # manually redisplay the dashboard
        if self.is_running() and self.enabled:
            self.render(True, style_changed)

    def inferior_pid(self):
        return gdb.selected_inferior().pid

    def is_running(self):
        return self.inferior_pid() != 0

    def render(self, clear_screen, style_changed=False):
        # fetch module content and info
        display_map = dict()
        for module in self.modules:
            if not module.enabled:
                continue
            # fall back to the global value
            output = module.output or self.output
            display_map.setdefault(output, []).append(module.instance)
        # notify the user if the output is empty, on the main terminal
        if not display_map:
            # write the error message
            width = Dashboard.get_term_width()
            gdb.write(divider(width, 'Error', True))
            gdb.write('\n')
            if self.modules:
                gdb.write('No module to display (see `help dashboard`)')
            else:
                gdb.write('No module loaded')
            # write the terminator
            gdb.write('\n')
            gdb.write(divider(width, primary=True))
            gdb.write('\n')
            gdb.flush()
            return
        # process each display info
        for output, instances in display_map.items():
            try:
                fs = None
                # use GDB stream by default
                if output:
                    fs = open(output, 'w')
                    fd = fs.fileno()
                    # setup the terminal
                    fs.write(Dashboard.hide_cursor())
                else:
                    fs = gdb
                    fd = 1
                # get the terminal width (default main terminal if either
                # the output is not a file)
                try:
                    width = Dashboard.get_term_width(fd)
                except:
                    width = Dashboard.get_term_width()
                # clear the "screen" if requested for the main terminal,
                # auxiliary terminals are always cleared
                if fs is not gdb or clear_screen:
                    fs.write(Dashboard.clear_screen())
                # process all the modules for that output
                for n, instance in enumerate(instances, 1):
                    # ask the module to generate the content
                    lines = instance.lines(width, style_changed)
                    # create the divider accordingly
                    div = divider(width, instance.label(), True, lines)
                    # write the data
                    fs.write('\n'.join([div] + lines))
                    # write the newline for all but last unless main terminal
                    if n != len(instances) or fs is gdb:
                        fs.write('\n')
                # write the final newline and the terminator only if it is the
                # main terminal to allow the prompt to display correctly
                if fs is gdb:
                    fs.write(divider(width, primary=True))
                    fs.write('\n')
                fs.flush()
            except Exception as e:
                cause = traceback.format_exc().strip()
                Dashboard.err('Cannot write the dashboard\n{}'.format(cause))
            finally:
                # don't close gdb stream
                if fs is not gdb:
                    fs.close()

# Utility methods --------------------------------------------------------------

    @staticmethod
    def start():
        # initialize the dashboard
        dashboard = Dashboard()
        Dashboard.set_custom_prompt(dashboard)
        # parse Python inits, load modules then parse GDB inits
        Dashboard.parse_inits(True)
        modules = Dashboard.get_modules()
        dashboard.load_modules(modules)
        Dashboard.parse_inits(False)
        # GDB overrides
        run('set pagination off')
        # enable and display if possible (program running)
        dashboard.enable()
        dashboard.redisplay()

    @staticmethod
    def get_term_width(fd=1):  # defaults to the main terminal
        # first 2 shorts (4 byte) of struct winsize
        raw = fcntl.ioctl(fd, termios.TIOCGWINSZ, ' ' * 4)
        height, width = struct.unpack('hh', raw)
        return int(width)

    @staticmethod
    def set_custom_prompt(dashboard):
        def custom_prompt(_):
            # render thread status indicator
            if dashboard.is_running():
                pid = dashboard.inferior_pid()
                status = R.prompt_running.format(pid=pid)
            else:
                status = R.prompt_not_running
            # build prompt
            prompt = R.prompt.format(status=status)
            prompt = gdb.prompt.substitute_prompt(prompt)
            return prompt + ' '  # force trailing space
        gdb.prompt_hook = custom_prompt

    @staticmethod
    def parse_inits(python):
        for root, dirs, files in os.walk(os.path.expanduser('~/.gdbinit.d/')):
            dirs.sort()
            for init in sorted(files):
                path = os.path.join(root, init)
                _, ext = os.path.splitext(path)
                # either load Python files or GDB
                if python ^ (ext != '.py'):
                    gdb.execute('source ' + path)

    @staticmethod
    def get_modules():
        # scan the scope for modules
        modules = []
        for name in globals():
            obj = globals()[name]
            try:
                if issubclass(obj, Dashboard.Module):
                    modules.append(obj)
            except TypeError:
                continue
        # sort modules alphabetically
        modules.sort(key=lambda x: x.__name__)
        return modules

    @staticmethod
    def create_command(name, invoke, doc, is_prefix, complete=None):
        Class = type('', (gdb.Command,), {'invoke': invoke, '__doc__': doc})
        Class(name, gdb.COMMAND_USER, complete or gdb.COMPLETE_NONE, is_prefix)

    @staticmethod
    def err(string):
        print(ansi(string, R.style_error))

    @staticmethod
    def complete(word, candidates):
        return filter(lambda candidate: candidate.startswith(word), candidates)

    @staticmethod
    def parse_arg(arg):
        # encode unicode GDB command arguments as utf8 in Python 2.7
        if type(arg) is not str:
            arg = arg.encode('utf8')
        return arg

    @staticmethod
    def clear_screen():
        # ANSI: move the cursor to top-left corner and clear the screen
        return '\x1b[H\x1b[J'

    @staticmethod
    def hide_cursor():
        # ANSI: hide cursor
        return '\x1b[?25l'

    @staticmethod
    def reset_terminal():
        # ANSI: reset to initial state
        return '\x1bc'

# Module descriptor ------------------------------------------------------------

    class ModuleInfo:

        def __init__(self, dashboard, module):
            self.name = module.__name__.lower()  # from class to module name
            self.enabled = True
            self.output = None  # value from the dashboard by default
            self.instance = module()
            self.doc = self.instance.__doc__ or '(no documentation)'
            self.prefix = 'dashboard {}'.format(self.name)
            # add GDB commands
            self.add_main_command(dashboard)
            self.add_output_command(dashboard)
            self.add_style_command(dashboard)
            self.add_subcommands(dashboard)

        def add_main_command(self, dashboard):
            module = self
            def invoke(self, arg, from_tty, info=self):
                arg = Dashboard.parse_arg(arg)
                if arg == '':
                    info.enabled ^= True
                    if dashboard.is_running():
                        dashboard.redisplay()
                    else:
                        status = 'enabled' if info.enabled else 'disabled'
                        print('{} module {}'.format(module.name, status))
                else:
                    Dashboard.err('Wrong argument "{}"'.format(arg))
            doc_brief = 'Configure the {} module.'.format(self.name)
            doc_extended = 'Toggle the module visibility.'
            doc = '{}\n{}\n\n{}'.format(doc_brief, doc_extended, self.doc)
            Dashboard.create_command(self.prefix, invoke, doc, True)

        def add_output_command(self, dashboard):
            Dashboard.OutputCommand(dashboard, self.prefix, self)

        def add_style_command(self, dashboard):
            if 'attributes' in dir(self.instance):
                Dashboard.StyleCommand(dashboard, self.prefix, self.instance,
                                       self.instance.attributes())

        def add_subcommands(self, dashboard):
            if 'commands' in dir(self.instance):
                for name, command in self.instance.commands().items():
                    self.add_subcommand(dashboard, name, command)

        def add_subcommand(self, dashboard, name, command):
            action = command['action']
            doc = command['doc']
            complete = command.get('complete')
            def invoke(self, arg, from_tty, info=self):
                arg = Dashboard.parse_arg(arg)
                if info.enabled:
                    try:
                        action(arg)
                    except Exception as e:
                        Dashboard.err(e)
                        return
                    # don't catch redisplay errors
                    dashboard.redisplay()
                else:
                    Dashboard.err('Module disabled')
            prefix = '{} {}'.format(self.prefix, name)
            Dashboard.create_command(prefix, invoke, doc, False, complete)

# GDB commands -----------------------------------------------------------------

    def invoke(self, arg, from_tty):
        arg = Dashboard.parse_arg(arg)
        # show messages for checks in redisplay
        if arg != '':
            Dashboard.err('Wrong argument "{}"'.format(arg))
        elif not self.is_running():
            Dashboard.err('Is the target program running?')
        else:
            self.redisplay()

    class ConfigurationCommand(gdb.Command):
        """Dump the dashboard configuration (layout, styles, outputs).
With an optional argument the configuration will be written to the specified
file."""

        def __init__(self, dashboard):
            gdb.Command.__init__(self, 'dashboard -configuration',
                                 gdb.COMMAND_USER, gdb.COMPLETE_FILENAME)
            self.dashboard = dashboard

        def invoke(self, arg, from_tty):
            arg = Dashboard.parse_arg(arg)
            if arg:
                with open(os.path.expanduser(arg), 'w') as fs:
                    fs.write('# auto generated by GDB dashboard\n\n')
                    self.dump(fs)
            self.dump(gdb)

        def dump(self, fs):
            # dump layout
            self.dump_layout(fs)
            # dump styles
            self.dump_style(fs, R)
            for module in self.dashboard.modules:
                self.dump_style(fs, module.instance, module.prefix)
            # dump outputs
            self.dump_output(fs, self.dashboard)
            for module in self.dashboard.modules:
                self.dump_output(fs, module, module.prefix)

        def dump_layout(self, fs):
            layout = ['dashboard -layout']
            for module in self.dashboard.modules:
                mark = '' if module.enabled else '!'
                layout.append('{}{}'.format(mark, module.name))
            fs.write(' '.join(layout))
            fs.write('\n')

        def dump_style(self, fs, obj, prefix='dashboard'):
            attributes = getattr(obj, 'attributes', lambda: dict())()
            for name, attribute in attributes.items():
                real_name = attribute.get('name', name)
                default = attribute.get('default')
                value = getattr(obj, real_name)
                if value != default:
                    fs.write('{} -style {} {!r}\n'.format(prefix, name, value))

        def dump_output(self, fs, obj, prefix='dashboard'):
            output = getattr(obj, 'output')
            if output:
                fs.write('{} -output {}\n'.format(prefix, output))

    class OutputCommand(gdb.Command):
        """Set the output file/TTY for both the dashboard and modules.
The dashboard/module will be written to the specified file, which will be
created if it does not exist. If the specified file identifies a terminal then
its width will be used to format the dashboard, otherwise falls back to the
width of the main GDB terminal. Without argument the dashboard, the
output/messages and modules which do not specify the output will be printed on
standard output (default). Without argument the module will be printed where the
dashboard will be printed."""

        def __init__(self, dashboard, prefix=None, obj=None):
            if not prefix:
                prefix = 'dashboard'
            if not obj:
                obj = dashboard
            prefix = prefix + ' -output'
            gdb.Command.__init__(self, prefix,
                                 gdb.COMMAND_USER, gdb.COMPLETE_FILENAME)
            self.dashboard = dashboard
            self.obj = obj  # None means the dashboard itself

        def invoke(self, arg, from_tty):
            arg = Dashboard.parse_arg(arg)
            # set or open the output file
            if arg == '':
                self.obj.output = None
            else:
                self.obj.output = arg
            # redisplay the dashboard in the new output
            self.dashboard.redisplay()

    class EnabledCommand(gdb.Command):
        """Enable or disable the dashboard [on|off].
The current status is printed if no argument is present."""

        def __init__(self, dashboard):
            gdb.Command.__init__(self, 'dashboard -enabled', gdb.COMMAND_USER)
            self.dashboard = dashboard

        def invoke(self, arg, from_tty):
            arg = Dashboard.parse_arg(arg)
            if arg == '':
                status = 'enabled' if self.dashboard.enabled else 'disabled'
                print('The dashboard is {}'.format(status))
            elif arg == 'on':
                self.dashboard.enable()
                self.dashboard.redisplay()
            elif arg == 'off':
                self.dashboard.disable()
            else:
                msg = 'Wrong argument "{}"; expecting "on" or "off"'
                Dashboard.err(msg.format(arg))

        def complete(self, text, word):
            return Dashboard.complete(word, ['on', 'off'])

    class LayoutCommand(gdb.Command):
        """Set or show the dashboard layout.
Accepts a space-separated list of directive. Each directive is in the form
"[!]<module>". Modules in the list are placed in the dashboard in the same order
as they appear and those prefixed by "!" are disabled by default. Omitted
modules are hidden and placed at the bottom in alphabetical order. Without
arguments the current layout is shown where the first line uses the same form
expected by the input while the remaining depict the current status of output
files."""

        def __init__(self, dashboard):
            gdb.Command.__init__(self, 'dashboard -layout', gdb.COMMAND_USER)
            self.dashboard = dashboard

        def invoke(self, arg, from_tty):
            arg = Dashboard.parse_arg(arg)
            directives = str(arg).split()
            if directives:
                self.layout(directives)
                if from_tty and not self.dashboard.is_running():
                    self.show()
            else:
                self.show()

        def show(self):
            global_str = 'Global'
            max_name_len = len(global_str)
            # print directives
            modules = []
            for module in self.dashboard.modules:
                max_name_len = max(max_name_len, len(module.name))
                mark = '' if module.enabled else '!'
                modules.append('{}{}'.format(mark, module.name))
            print(' '.join(modules))
            # print outputs
            default = '(default)'
            fmt = '{{:{}s}}{{}}'.format(max_name_len + 2)
            print(('\n' + fmt + '\n').format(global_str,
                                             self.dashboard.output or default))
            for module in self.dashboard.modules:
                style = R.style_high if module.enabled else R.style_low
                line = fmt.format(module.name, module.output or default)
                print(ansi(line, style))

        def layout(self, directives):
            modules = self.dashboard.modules
            # reset visibility
            for module in modules:
                module.enabled = False
            # move and enable the selected modules on top
            last = 0
            n_enabled = 0
            for directive in directives:
                # parse next directive
                enabled = (directive[0] != '!')
                name = directive[not enabled:]
                try:
                    # it may actually start from last, but in this way repeated
                    # modules can be handled transparently and without error
                    todo = enumerate(modules[last:], start=last)
                    index = next(i for i, m in todo if name == m.name)
                    modules[index].enabled = enabled
                    modules.insert(last, modules.pop(index))
                    last += 1
                    n_enabled += enabled
                except StopIteration:
                    def find_module(x):
                        return x.name == name
                    first_part = modules[:last]
                    if len(list(filter(find_module, first_part))) == 0:
                        Dashboard.err('Cannot find module "{}"'.format(name))
                    else:
                        Dashboard.err('Module "{}" already set'.format(name))
                    continue
            # redisplay the dashboard
            if n_enabled:
                self.dashboard.redisplay()

        def complete(self, text, word):
            all_modules = (m.name for m in self.dashboard.modules)
            return Dashboard.complete(word, all_modules)

    class StyleCommand(gdb.Command):
        """Access the stylable attributes.
Without arguments print all the stylable attributes. Subcommands are used to set
or print (when the value is omitted) individual attributes."""

        def __init__(self, dashboard, prefix, obj, attributes):
            self.prefix = prefix + ' -style'
            gdb.Command.__init__(self, self.prefix,
                                 gdb.COMMAND_USER, gdb.COMPLETE_NONE, True)
            self.dashboard = dashboard
            self.obj = obj
            self.attributes = attributes
            self.add_styles()

        def add_styles(self):
            this = self
            for name, attribute in self.attributes.items():
                # fetch fields
                attr_name = attribute.get('name', name)
                attr_type = attribute.get('type', str)
                attr_check = attribute.get('check', lambda _: True)
                attr_default = attribute['default']
                # set the default value (coerced to the type)
                value = attr_type(attr_default)
                setattr(self.obj, attr_name, value)
                # create the command
                def invoke(self, arg, from_tty, name=name, attr_name=attr_name,
                           attr_type=attr_type, attr_check=attr_check):
                    new_value = Dashboard.parse_arg(arg)
                    if new_value == '':
                        # print the current value
                        value = getattr(this.obj, attr_name)
                        print('{} = {!r}'.format(name, value))
                    else:
                        try:
                            # convert and check the new value
                            parsed = ast.literal_eval(new_value)
                            value = attr_type(parsed)
                            if not attr_check(value):
                                msg = 'Invalid value "{}" for "{}"'
                                raise Exception(msg.format(new_value, name))
                        except Exception as e:
                            Dashboard.err(e)
                        else:
                            # set and redisplay
                            setattr(this.obj, attr_name, value)
                            this.dashboard.redisplay(True)
                prefix = self.prefix + ' ' + name
                doc = attribute.get('doc', 'This style is self-documenting')
                Dashboard.create_command(prefix, invoke, doc, False)

        def invoke(self, arg, from_tty):
            # an argument here means that the provided attribute is invalid
            if arg:
                Dashboard.err('Invalid argument "{}"'.format(arg))
                return
            # print all the pairs
            for name, attribute in self.attributes.items():
                attr_name = attribute.get('name', name)
                value = getattr(self.obj, attr_name)
                print('{} = {!r}'.format(name, value))

# Base module ------------------------------------------------------------------

    # just a tag
    class Module():
        pass

# Default modules --------------------------------------------------------------

class Source(Dashboard.Module):
    """Show the program source code, if available."""

    def __init__(self):
        self.file_name = None
        self.source_lines = []
        self.ts = None
        self.highlighted = False

    def label(self):
        return 'Source'

    def lines(self, term_width, style_changed):
        # skip if the current thread is not stopped
        if not gdb.selected_thread().is_stopped():
            return []
        # try to fetch the current line (skip if no line information)
        sal = gdb.selected_frame().find_sal()
        current_line = sal.line
        if current_line == 0:
            return []
        # reload the source file if changed
        file_name = sal.symtab.fullname()
        ts = None
        try:
            ts = os.path.getmtime(file_name)
        except:
            pass  # delay error check to open()
        if (style_changed or
                file_name != self.file_name or  # different file name
                ts and ts > self.ts):  # file modified in the meanwhile
            self.file_name = file_name
            self.ts = ts
            try:
                highlighter = Beautifier(self.file_name, self.tab_size)
                self.highlighted = highlighter.active
                with open(self.file_name) as source_file:
                    source = highlighter.process(source_file.read())
                    self.source_lines = source.split('\n')
            except Exception as e:
                msg = 'Cannot display "{}" ({})'.format(self.file_name, e)
                return [ansi(msg, R.style_error)]
        # compute the line range
        start = max(current_line - 1 - self.context, 0)
        end = min(current_line - 1 + self.context + 1, len(self.source_lines))
        # return the source code listing
        out = []
        number_format = '{{:>{}}}'.format(len(str(end)))
        for number, line in enumerate(self.source_lines[start:end], start + 1):
            # properly handle UTF-8 source files
            line = to_string(line)
            if int(number) == current_line:
                # the current line has a different style without ANSI
                if R.ansi:
                    if self.highlighted:
                        line_format = ansi(number_format,
                                           R.style_selected_1) + ' {}'
                    else:
                        line_format = ansi(number_format + ' {}',
                                           R.style_selected_1)
                else:
                    # just show a plain text indicator
                    line_format = number_format + '>{}'
            else:
                line_format = ansi(number_format, R.style_low) + ' {}'
            out.append(line_format.format(number, line.rstrip('\n')))
        return out

    def attributes(self):
        return {
            'context': {
                'doc': 'Number of context lines.',
                'default': 5,
                'type': int,
                'check': check_ge_zero
            },
            'tab-size': {
                'doc': 'Number of spaces used to display the tab character.',
                'default': 4,
                'name': 'tab_size',
                'type': int,
                'check': check_gt_zero
            }
        }

class Assembly(Dashboard.Module):
    """Show the disassembled code surrounding the program counter. The
instructions constituting the current statement are marked, if available."""

    def label(self):
        return 'Assembly'

    def lines(self, term_width, style_changed):
        # skip if the current thread is not stopped
        if not gdb.selected_thread().is_stopped():
            return []
        line_info = None
        frame = gdb.selected_frame()  # PC is here
        disassemble = frame.architecture().disassemble
        try:
            # try to fetch the function boundaries using the disassemble command
            output = run('disassemble').split('\n')
            start = int(re.split('[ :]', output[1][3:], 1)[0], 16)
            end = int(re.split('[ :]', output[-3][3:], 1)[0], 16)
            asm = disassemble(start, end_pc=end)
            # find the location of the PC
            pc_index = next(index for index, instr in enumerate(asm)
                            if instr['addr'] == frame.pc())
            start = max(pc_index - self.context, 0)
            end = pc_index + self.context + 1
            asm = asm[start:end]
            # if there are line information then use it, it may be that
            # line_info is not None but line_info.last is None
            line_info = gdb.find_pc_line(frame.pc())
            line_info = line_info if line_info.last else None
        except (gdb.error, StopIteration):
            # if it is not possible (stripped binary or the PC is not present in
            # the output of `disassemble` as per issue #31) start from PC and
            # end after twice the context
            asm = disassemble(frame.pc(), count=2 * self.context + 1)
        # fetch function start if available
        func_start = None
        if self.show_function and frame.name():
            try:
                # it may happen that the frame name is the whole function
                # declaration, instead of just the name, e.g., 'getkey()', so it
                # would be treated as a function call by 'gdb.parse_and_eval',
                # hence the trim, see #87 and #88
                value = gdb.parse_and_eval(frame.name().split('(')[0]).address
                func_start = to_unsigned(value)
            except gdb.error:
                pass  # e.g., @plt
        # fetch the assembly flavor and the extension used by Pygments
        try:
            flavor = gdb.parameter('disassembly-flavor')
        except:
            flavor = None  # not always defined (see #36)
        filename = {
            'att': '.s',
            'intel': '.asm'
        }.get(flavor, '.s')
        # prepare the highlighter
        highlighter = Beautifier(filename)
        # compute the maximum offset size
        if func_start:
            max_offset = max(len(str(abs(asm[0]['addr'] - func_start))),
                             len(str(abs(asm[-1]['addr'] - func_start))))
        # return the machine code
        max_length = max(instr['length'] for instr in asm)
        inferior = gdb.selected_inferior()
        out = []
        for index, instr in enumerate(asm):
            addr = instr['addr']
            length = instr['length']
            text = instr['asm']
            addr_str = format_address(addr)
            if self.show_opcodes:
                # fetch and format opcode
                region = inferior.read_memory(addr, length)
                opcodes = (' '.join('{:02x}'.format(ord(byte))
                                    for byte in region))
                opcodes += (max_length - len(region)) * 3 * ' ' + ' '
            else:
                opcodes = ''
            # compute the offset if available
            if self.show_function:
                if func_start:
                    offset = '{:+d}'.format(addr - func_start)
                    offset = offset.ljust(max_offset + 1)  # sign
                    func_info = '{}{} '.format(frame.name(), offset)
                else:
                    func_info = '? '
            else:
                func_info = ''
            format_string = '{}{}{}{}{}'
            indicator = ' '
            text = highlighter.process(text)
            if addr == frame.pc():
                if not R.ansi:
                    indicator = '>'
                addr_str = ansi(addr_str, R.style_selected_1)
                opcodes = ansi(opcodes, R.style_selected_1)
                func_info = ansi(func_info, R.style_selected_1)
                if not highlighter.active:
                    text = ansi(text, R.style_selected_1)
            elif line_info and line_info.pc <= addr < line_info.last:
                if not R.ansi:
                    indicator = ':'
                addr_str = ansi(addr_str, R.style_selected_2)
                opcodes = ansi(opcodes, R.style_selected_2)
                func_info = ansi(func_info, R.style_selected_2)
                if not highlighter.active:
                    text = ansi(text, R.style_selected_2)
            else:
                addr_str = ansi(addr_str, R.style_low)
                func_info = ansi(func_info, R.style_low)
            out.append(format_string.format(addr_str, indicator,
                                            opcodes, func_info, text))
        return out

    def attributes(self):
        return {
            'context': {
                'doc': 'Number of context instructions.',
                'default': 3,
                'type': int,
                'check': check_ge_zero
            },
            'opcodes': {
                'doc': 'Opcodes visibility flag.',
                'default': False,
                'name': 'show_opcodes',
                'type': bool
            },
            'function': {
                'doc': 'Function information visibility flag.',
                'default': True,
                'name': 'show_function',
                'type': bool
            }
        }

class Stack(Dashboard.Module):
    """Show the current stack trace including the function name and the file
location, if available. Optionally list the frame arguments and locals too."""

    def label(self):
        return 'Stack'

    def lines(self, term_width, style_changed):
        # skip if the current thread is not stopped
        if not gdb.selected_thread().is_stopped():
            return []
        # find the selected frame (i.e., the first to display)
        selected_index = 0
        frame = gdb.newest_frame()
        while frame:
            if frame == gdb.selected_frame():
                break
            frame = frame.older()
            selected_index += 1
        # format up to "limit" frames
        frames = []
        number = selected_index
        more = False
        while frame:
            # the first is the selected one
            selected = (len(frames) == 0)
            # fetch frame info
            style = R.style_selected_1 if selected else R.style_selected_2
            frame_id = ansi(str(number), style)
            info = Stack.get_pc_line(frame, style)
            frame_lines = []
            frame_lines.append('[{}] {}'.format(frame_id, info))
            # fetch frame arguments and locals
            decorator = gdb.FrameDecorator.FrameDecorator(frame)
            separator = ansi(', ', R.style_low)
            strip_newlines = re.compile(r'$\s*', re.MULTILINE)
            if self.show_arguments:
                def prefix(line):
                    return Stack.format_line('arg', line)
                frame_args = decorator.frame_args()
                args_lines = Stack.fetch_frame_info(frame, frame_args)
                if args_lines:
                    if self.compact:
                        args_line = separator.join(args_lines)
                        args_line = strip_newlines.sub('', args_line)
                        single_line = prefix(args_line)
                        frame_lines.append(single_line)
                    else:
                        frame_lines.extend(map(prefix, args_lines))
                else:
                    frame_lines.append(ansi('(no arguments)', R.style_low))
            if self.show_locals:
                def prefix(line):
                    return Stack.format_line('loc', line)
                frame_locals = decorator.frame_locals()
                locals_lines = Stack.fetch_frame_info(frame, frame_locals)
                if locals_lines:
                    if self.compact:
                        locals_line = separator.join(locals_lines)
                        locals_line = strip_newlines.sub('', locals_line)
                        single_line = prefix(locals_line)
                        frame_lines.append(single_line)
                    else:
                        frame_lines.extend(map(prefix, locals_lines))
                else:
                    frame_lines.append(ansi('(no locals)', R.style_low))
            # add frame
            frames.append(frame_lines)
            # next
            frame = frame.older()
            number += 1
            # check finished according to the limit
            if self.limit and len(frames) == self.limit:
                # more frames to show but limited
                if frame:
                    more = True
                break
        # format the output
        lines = []
        for frame_lines in frames:
            lines.extend(frame_lines)
        # add the placeholder
        if more:
            lines.append('[{}]'.format(ansi('+', R.style_selected_2)))
        return lines

    @staticmethod
    def format_line(prefix, line):
        prefix = ansi(prefix, R.style_low)
        return '{} {}'.format(prefix, line)

    @staticmethod
    def fetch_frame_info(frame, data):
        lines = []
        for elem in data or []:
            name = elem.sym
            equal = ansi('=', R.style_low)
            value = to_string(elem.sym.value(frame))
            lines.append('{} {} {}'.format(name, equal, value))
        return lines

    @staticmethod
    def get_pc_line(frame, style):
        frame_pc = ansi(format_address(frame.pc()), style)
        info = 'from {}'.format(frame_pc)
        if frame.name():
            frame_name = ansi(frame.name(), style)
            try:
                # try to compute the offset relative to the current function (it
                # may happen that the frame name is the whole function
                # declaration, instead of just the name, e.g., 'getkey()', so it
                # would be treated as a function call by 'gdb.parse_and_eval',
                # hence the trim, see #87 and #88)
                value = gdb.parse_and_eval(frame.name().split('(')[0]).address
                # it can be None even if it is part of the "stack" (C++)
                if value:
                    func_start = to_unsigned(value)
                    offset = frame.pc() - func_start
                    frame_name += '+' + ansi(str(offset), style)
            except gdb.error:
                pass  # e.g., @plt
            info += ' in {}'.format(frame_name)
            sal = frame.find_sal()
            if sal.symtab:
                file_name = ansi(sal.symtab.filename, style)
                file_line = ansi(str(sal.line), style)
                info += ' at {}:{}'.format(file_name, file_line)
        return info

    def attributes(self):
        return {
            'limit': {
                'doc': 'Maximum number of displayed frames (0 means no limit).',
                'default': 2,
                'type': int,
                'check': check_ge_zero
            },
            'arguments': {
                'doc': 'Frame arguments visibility flag.',
                'default': True,
                'name': 'show_arguments',
                'type': bool
            },
            'locals': {
                'doc': 'Frame locals visibility flag.',
                'default': False,
                'name': 'show_locals',
                'type': bool
            },
            'compact': {
                'doc': 'Single-line display flag.',
                'default': False,
                'type': bool
            }
        }

class History(Dashboard.Module):
    """List the last entries of the value history."""

    def label(self):
        return 'History'

    def lines(self, term_width, style_changed):
        out = []
        # fetch last entries
        for i in range(-self.limit + 1, 1):
            try:
                value = to_string(gdb.history(i))
                value_id = ansi('$${}', R.style_low).format(abs(i))
                line = '{} = {}'.format(value_id, value)
                out.append(line)
            except gdb.error:
                continue
        return out

    def attributes(self):
        return {
            'limit': {
                'doc': 'Maximum number of values to show.',
                'default': 3,
                'type': int,
                'check': check_gt_zero
            }
        }

class Memory(Dashboard.Module):
    """Allow to inspect memory regions."""

    @staticmethod
    def format_byte(byte):
        # `type(byte) is bytes` in Python 3
        if byte.isspace():
            return ' '
        elif 0x20 < ord(byte) < 0x7e:
            return chr(ord(byte))
        else:
            return '.'

    @staticmethod
    def parse_as_address(expression):
        value = gdb.parse_and_eval(expression)
        return to_unsigned(value)

    def __init__(self):
        self.row_length = 16
        self.table = {}

    def format_memory(self, start, memory):
        out = []
        for i in range(0, len(memory), self.row_length):
            region = memory[i:i + self.row_length]
            pad = self.row_length - len(region)
            address = format_address(start + i)
            hexa = (' '.join('{:02x}'.format(ord(byte)) for byte in region))
            text = (''.join(Memory.format_byte(byte) for byte in region))
            out.append('{} {}{} {}{}'.format(ansi(address, R.style_low),
                                             hexa,
                                             ansi(pad * ' --', R.style_low),
                                             ansi(text, R.style_high),
                                             ansi(pad * '.', R.style_low)))
        return out

    def label(self):
        return 'Memory'

    def lines(self, term_width, style_changed):
        out = []
        inferior = gdb.selected_inferior()
        for address, length in sorted(self.table.items()):
            try:
                memory = inferior.read_memory(address, length)
                out.extend(self.format_memory(address, memory))
            except gdb.error:
                msg = 'Cannot access {} bytes starting at {}'
                msg = msg.format(length, format_address(address))
                out.append(ansi(msg, R.style_error))
            out.append(divider(term_width))
        # drop last divider
        if out:
            del out[-1]
        return out

    def watch(self, arg):
        if arg:
            address, _, length = arg.partition(' ')
            address = Memory.parse_as_address(address)
            if length:
                length = Memory.parse_as_address(length)
            else:
                length = self.row_length
            self.table[address] = length
        else:
            raise Exception('Specify an address')

    def unwatch(self, arg):
        if arg:
            try:
                del self.table[Memory.parse_as_address(arg)]
            except KeyError:
                raise Exception('Memory region not watched')
        else:
            raise Exception('Specify an address')

    def clear(self, arg):
        self.table.clear()

    def commands(self):
        return {
            'watch': {
                'action': self.watch,
                'doc': 'Watch a memory region by address and length.\n'
                       'The length defaults to 16 byte.',
                'complete': gdb.COMPLETE_EXPRESSION
            },
            'unwatch': {
                'action': self.unwatch,
                'doc': 'Stop watching a memory region by address.',
                'complete': gdb.COMPLETE_EXPRESSION
            },
            'clear': {
                'action': self.clear,
                'doc': 'Clear all the watched regions.'
            }
        }

class Registers(Dashboard.Module):
    """Show the CPU registers and their values."""

    def __init__(self):
        self.table = {}

    def label(self):
        return 'Registers'

    def lines(self, term_width, style_changed):
        # skip if the current thread is not stopped
        if not gdb.selected_thread().is_stopped():
            return []
        # fetch registers status
        registers = []
        for reg_info in run('info registers').strip().split('\n'):
            # fetch register and update the table
            name = reg_info.split(None, 1)[0]
            # Exclude registers with a dot '.' or parse_and_eval() will fail
            if '.' in name:
                continue
            value = gdb.parse_and_eval('${}'.format(name))
            string_value = Registers.format_value(value)
            changed = self.table and (self.table.get(name, '') != string_value)
            self.table[name] = string_value
            registers.append((name, string_value, changed))
        # split registers in rows and columns, each column is composed of name,
        # space, value and another trailing space which is skipped in the last
        # column (hence term_width + 1)
        max_name = max(len(name) for name, _, _ in registers)
        max_value = max(len(value) for _, value, _ in registers)
        max_width = max_name + max_value + 2
        per_line = int((term_width + 1) / max_width) or 1
        # redistribute extra space among columns
        extra = int((term_width + 1 - max_width * per_line) / per_line)
        if per_line == 1:
            # center when there is only one column
            max_name += int(extra / 2)
            max_value += int(extra / 2)
        else:
            max_value += extra
        # format registers info
        partial = []
        for name, value, changed in registers:
            styled_name = ansi(name.rjust(max_name), R.style_low)
            value_style = R.style_selected_1 if changed else ''
            styled_value = ansi(value.ljust(max_value), value_style)
            partial.append(styled_name + ' ' + styled_value)
        out = []
        if self.column_major:
            num_lines = int(math.ceil(float(len(partial)) / per_line))
            for i in range(num_lines):
                line = ' '.join(partial[i:len(partial):num_lines]).rstrip()
                real_n_col = math.ceil(float(len(partial)) / num_lines)
                line = ' ' * int((per_line - real_n_col) * max_width / 2) + line
                out.append(line)
        else:
            for i in range(0, len(partial), per_line):
                out.append(' '.join(partial[i:i + per_line]).rstrip())
        return out

    def attributes(self):
        return {
            'column-major': {
                'doc': 'Whether to show registers in columns instead of rows.',
                'default': False,
                'name': 'column_major',
                'type': bool
            }
        }

    @staticmethod
    def format_value(value):
        try:
            if value.type.code in [gdb.TYPE_CODE_INT, gdb.TYPE_CODE_PTR]:
                int_value = to_unsigned(value, value.type.sizeof)
                value_format = '0x{{:0{}x}}'.format(2 * value.type.sizeof)
                return value_format.format(int_value)
        except (gdb.error, ValueError):
            # convert to unsigned but preserve code and flags information
            pass
        return str(value)

class Threads(Dashboard.Module):
    """List the currently available threads."""

    def label(self):
        return 'Threads'

    def lines(self, term_width, style_changed):
        out = []
        selected_thread = gdb.selected_thread()
        # do not restore the selected frame if the thread is not stopped
        restore_frame = gdb.selected_thread().is_stopped()
        if restore_frame:
            selected_frame = gdb.selected_frame()
        for thread in gdb.Inferior.threads(gdb.selected_inferior()):
            # skip running threads if requested
            if self.skip_running and thread.is_running():
                continue
            is_selected = (thread.ptid == selected_thread.ptid)
            style = R.style_selected_1 if is_selected else R.style_selected_2
            number = ansi(str(thread.num), style)
            tid = ansi(str(thread.ptid[1] or thread.ptid[2]), style)
            info = '[{}] id {}'.format(number, tid)
            if thread.name:
                info += ' name {}'.format(ansi(thread.name, style))
            # switch thread to fetch frame info (unless is running in non-stop mode)
            try:
                thread.switch()
                frame = gdb.newest_frame()
                info += ' ' + Stack.get_pc_line(frame, style)
            except gdb.error:
                info += ' (running)'
            out.append(info)
        # restore thread and frame
        selected_thread.switch()
        if restore_frame:
            selected_frame.select()
        return out

    def attributes(self):
        return {
            'skip-running': {
                'doc': 'Skip running threads.',
                'default': False,
                'name': 'skip_running',
                'type': bool
            }
        }

class Expressions(Dashboard.Module):
    """Watch user expressions."""

    def __init__(self):
        self.number = 1
        self.table = {}

    def label(self):
        return 'Expressions'

    def lines(self, term_width, style_changed):
        out = []
        for number, expression in sorted(self.table.items()):
            try:
                value = to_string(gdb.parse_and_eval(expression))
            except gdb.error as e:
                value = ansi(e, R.style_error)
            number = ansi(number, R.style_selected_2)
            expression = ansi(expression, R.style_low)
            out.append('[{}] {} = {}'.format(number, expression, value))
        return out

    def watch(self, arg):
        if arg:
            self.table[self.number] = arg
            self.number += 1
        else:
            raise Exception('Specify an expression')

    def unwatch(self, arg):
        if arg:
            try:
                del self.table[int(arg)]
            except:
                raise Exception('Expression not watched')
        else:
            raise Exception('Specify an identifier')

    def clear(self, arg):
        self.table.clear()

    def commands(self):
        return {
            'watch': {
                'action': self.watch,
                'doc': 'Watch an expression.',
                'complete': gdb.COMPLETE_EXPRESSION
            },
            'unwatch': {
                'action': self.unwatch,
                'doc': 'Stop watching an expression by id.',
                'complete': gdb.COMPLETE_EXPRESSION
            },
            'clear': {
                'action': self.clear,
                'doc': 'Clear all the watched expressions.'
            }
        }

# XXX traceback line numbers in this Python block must be increased by 1
end

# Better GDB defaults ----------------------------------------------------------

set history save
set confirm off
set verbose off
set print pretty on
set print array on
set print array-indexes on
set python print-stack full


########################################################
# the following code is by @JpUsefRye | Youssef Hesham #
# youssefheshamhassan@gmail.com                        #
########################################################

set disassembly-flavor intel
set print pretty on
set print object on
set print static-members on
set print vtbl on
set print demangle on
set demangle-style gnu-v3
set print sevenbit-strings off

set $SHOW_CONTEXT = 1
set $SHOW_NEST_INSN = 0

set $CONTEXTSIZE_STACK = 6
set $CONTEXTSIZE_DATA  = 8
set $CONTEXTSIZE_CODE  = 8

# set to 0 to remove display of objectivec messages (default is 1)
set $SHOWOBJECTIVEC = 1

# set to 0 to remove display of cpu registers (default is 1)
set $SHOWCPUREGISTERS = 1

# set to 1 to enable display of stack (default is 0)
set $SHOWSTACK = 1

# set to 1 to enable display of data window (default is 0)
set $SHOWDATAWIN = 1


define contextsize-stack
    if $argc != 1
        help contextsize-stack
    else
        set $CONTEXTSIZE_STACK = $arg0
    end
end
document contextsize-stack
Set stack dump window size to NUM lines.
Usage: contextsize-stack NUM
end


define contextsize-data
    if $argc != 1
        help contextsize-data
    else
        set $CONTEXTSIZE_DATA = $arg0
    end
end
document contextsize-data
Set data dump window size to NUM lines.
Usage: contextsize-data NUM
end


define contextsize-code
    if $argc != 1
        help contextsize-code
    else
        set $CONTEXTSIZE_CODE = $arg0
    end
end
document contextsize-code
Set code window size to NUM lines.
Usage: contextsize-code NUM
end




#
# std::vector<>
#

define pvector
	if $argc == 0
		help pvector
	else
		set $size = $arg0._M_impl._M_finish - $arg0._M_impl._M_start
		set $capacity = $arg0._M_impl._M_end_of_storage - $arg0._M_impl._M_start
		set $size_max = $size - 1
	end
	if $argc == 1
		set $i = 0
		while $i < $size
			printf "elem[%u]: ", $i
			p *($arg0._M_impl._M_start + $i)
			set $i++
		end
	end
	if $argc == 2
		set $idx = $arg1
		if $idx < 0 || $idx > $size_max
			printf "idx1, idx2 are not in acceptable range: [0..%u].\n", $size_max
		else
			printf "elem[%u]: ", $idx
			p *($arg0._M_impl._M_start + $idx)
		end
	end
	if $argc == 3
	  set $start_idx = $arg1
	  set $stop_idx = $arg2
	  if $start_idx > $stop_idx
	    set $tmp_idx = $start_idx
	    set $start_idx = $stop_idx
	    set $stop_idx = $tmp_idx
	  end
	  if $start_idx < 0 || $stop_idx < 0 || $start_idx > $size_max || $stop_idx > $size_max
	    printf "idx1, idx2 are not in acceptable range: [0..%u].\n", $size_max
	  else
	    set $i = $start_idx
		while $i <= $stop_idx
			printf "elem[%u]: ", $i
			p *($arg0._M_impl._M_start + $i)
			set $i++
		end
	  end
	end
	if $argc > 0
		printf "Vector size = %u\n", $size
		printf "Vector capacity = %u\n", $capacity
		printf "Element "
		whatis $arg0._M_impl._M_start
	end
end

document pvector
	Prints std::vector<T> information.
	Syntax: pvector <vector> <idx1> <idx2>
	Note: idx, idx1 and idx2 must be in acceptable range [0..<vector>.size()-1].
	Examples:
	pvector v - Prints vector content, size, capacity and T typedef
	pvector v 0 - Prints element[idx] from vector
	pvector v 1 2 - Prints elements in range [idx1..idx2] from vector
end

# std::list<>

define plist
	if $argc == 0
		help plist
	else
		set $head = &$arg0._M_impl._M_node
		set $current = $arg0._M_impl._M_node._M_next
		set $size = 0
		while $current != $head
			if $argc == 2
				printf "elem[%u]: ", $size
				p *($arg1*)($current + 1)
			end
			if $argc == 3
				if $size == $arg2
					printf "elem[%u]: ", $size
					p *($arg1*)($current + 1)
				end
			end
			set $current = $current._M_next
			set $size++
		end
		printf "List size = %u \n", $size
		if $argc == 1
			printf "List "
			whatis $arg0
			printf "Use plist <variable_name> <element_type> to see the elements in the list.\n"
		end
	end
end

document plist
	Prints std::list<T> information.
	Syntax: plist <list> <T> <idx>: Prints list size, if T defined all elements or just element at idx
	Examples:
	plist l - prints list size and definition
	plist l int - prints all elements and list size
	plist l int 2 - prints the third element in the list (if exists) and list size
end

define plist_member
	if $argc == 0
		help plist_member
	else
		set $head = &$arg0._M_impl._M_node
		set $current = $arg0._M_impl._M_node._M_next
		set $size = 0
		while $current != $head
			if $argc == 3
				printf "elem[%u]: ", $size
				p (*($arg1*)($current + 1)).$arg2
			end
			if $argc == 4
				if $size == $arg3
					printf "elem[%u]: ", $size
					p (*($arg1*)($current + 1)).$arg2
				end
			end
			set $current = $current._M_next
			set $size++
		end
		printf "List size = %u \n", $size
		if $argc == 1
			printf "List "
			whatis $arg0
			printf "Use plist_member <variable_name> <element_type> <member> to see the elements in the list.\n"
		end
	end
end

document plist_member
	Prints std::list<T> information.
	Syntax: plist <list> <T> <idx>: Prints list size, if T defined all elements or just element at idx
	Examples:
	plist_member l int member - prints all elements and list size
	plist_member l int member 2 - prints the third element in the list (if exists) and list size
end

# std::map and std::multimap

define pmap
	if $argc == 0
		help pmap
	else
		set $tree = $arg0
		set $i = 0
		set $node = $tree._M_t._M_impl._M_header._M_left
		set $end = $tree._M_t._M_impl._M_header
		set $tree_size = $tree._M_t._M_impl._M_node_count
		if $argc == 1
			printf "Map "
			whatis $tree
			printf "Use pmap <variable_name> <left_element_type> <right_element_type> to see the elements in the map.\n"
		end
		if $argc == 3
			while $i < $tree_size
				set $value = (void *)($node + 1)
				printf "elem[%u].left: ", $i
				p *($arg1*)$value
				set $value = $value + sizeof($arg1)
				printf "elem[%u].right: ", $i
				p *($arg2*)$value
				if $node._M_right != 0
					set $node = $node._M_right
					while $node._M_left != 0
						set $node = $node._M_left
					end
				else
					set $tmp_node = $node._M_parent
					while $node == $tmp_node._M_right
						set $node = $tmp_node
						set $tmp_node = $tmp_node._M_parent
					end
					if $node._M_right != $tmp_node
						set $node = $tmp_node
					end
				end
				set $i++
			end
		end
		if $argc == 4
			set $idx = $arg3
			set $ElementsFound = 0
			while $i < $tree_size
				set $value = (void *)($node + 1)
				if *($arg1*)$value == $idx
					printf "elem[%u].left: ", $i
					p *($arg1*)$value
					set $value = $value + sizeof($arg1)
					printf "elem[%u].right: ", $i
					p *($arg2*)$value
					set $ElementsFound++
				end
				if $node._M_right != 0
					set $node = $node._M_right
					while $node._M_left != 0
						set $node = $node._M_left
					end
				else
					set $tmp_node = $node._M_parent
					while $node == $tmp_node._M_right
						set $node = $tmp_node
						set $tmp_node = $tmp_node._M_parent
					end
					if $node._M_right != $tmp_node
						set $node = $tmp_node
					end
				end
				set $i++
			end
			printf "Number of elements found = %u\n", $ElementsFound
		end
		if $argc == 5
			set $idx1 = $arg3
			set $idx2 = $arg4
			set $ElementsFound = 0
			while $i < $tree_size
				set $value = (void *)($node + 1)
				set $valueLeft = *($arg1*)$value
				set $valueRight = *($arg2*)($value + sizeof($arg1))
				if $valueLeft == $idx1 && $valueRight == $idx2
					printf "elem[%u].left: ", $i
					p $valueLeft
					printf "elem[%u].right: ", $i
					p $valueRight
					set $ElementsFound++
				end
				if $node._M_right != 0
					set $node = $node._M_right
					while $node._M_left != 0
						set $node = $node._M_left
					end
				else
					set $tmp_node = $node._M_parent
					while $node == $tmp_node._M_right
						set $node = $tmp_node
						set $tmp_node = $tmp_node._M_parent
					end
					if $node._M_right != $tmp_node
						set $node = $tmp_node
					end
				end
				set $i++
			end
			printf "Number of elements found = %u\n", $ElementsFound
		end
		printf "Map size = %u\n", $tree_size
	end
end

document pmap
	Prints std::map<TLeft and TRight> or std::multimap<TLeft and TRight> information. Works for std::multimap as well.
	Syntax: pmap <map> <TtypeLeft> <TypeRight> <valLeft> <valRight>: Prints map size, if T defined all elements or just element(s) with val(s)
	Examples:
	pmap m - prints map size and definition
	pmap m int int - prints all elements and map size
	pmap m int int 20 - prints the element(s) with left-value = 20 (if any) and map size
	pmap m int int 20 200 - prints the element(s) with left-value = 20 and right-value = 200 (if any) and map size
end


define pmap_member
	if $argc == 0
		help pmap_member
	else
		set $tree = $arg0
		set $i = 0
		set $node = $tree._M_t._M_impl._M_header._M_left
		set $end = $tree._M_t._M_impl._M_header
		set $tree_size = $tree._M_t._M_impl._M_node_count
		if $argc == 1
			printf "Map "
			whatis $tree
			printf "Use pmap <variable_name> <left_element_type> <right_element_type> to see the elements in the map.\n"
		end
		if $argc == 5
			while $i < $tree_size
				set $value = (void *)($node + 1)
				printf "elem[%u].left: ", $i
				p (*($arg1*)$value).$arg2
				set $value = $value + sizeof($arg1)
				printf "elem[%u].right: ", $i
				p (*($arg3*)$value).$arg4
				if $node._M_right != 0
					set $node = $node._M_right
					while $node._M_left != 0
						set $node = $node._M_left
					end
				else
					set $tmp_node = $node._M_parent
					while $node == $tmp_node._M_right
						set $node = $tmp_node
						set $tmp_node = $tmp_node._M_parent
					end
					if $node._M_right != $tmp_node
						set $node = $tmp_node
					end
				end
				set $i++
			end
		end
		if $argc == 6
			set $idx = $arg5
			set $ElementsFound = 0
			while $i < $tree_size
				set $value = (void *)($node + 1)
				if *($arg1*)$value == $idx
					printf "elem[%u].left: ", $i
					p (*($arg1*)$value).$arg2
					set $value = $value + sizeof($arg1)
					printf "elem[%u].right: ", $i
					p (*($arg3*)$value).$arg4
					set $ElementsFound++
				end
				if $node._M_right != 0
					set $node = $node._M_right
					while $node._M_left != 0
						set $node = $node._M_left
					end
				else
					set $tmp_node = $node._M_parent
					while $node == $tmp_node._M_right
						set $node = $tmp_node
						set $tmp_node = $tmp_node._M_parent
					end
					if $node._M_right != $tmp_node
						set $node = $tmp_node
					end
				end
				set $i++
			end
			printf "Number of elements found = %u\n", $ElementsFound
		end
		printf "Map size = %u\n", $tree_size
	end
end

document pmap_member
	Prints std::map<TLeft and TRight> or std::multimap<TLeft and TRight> information. Works for std::multimap as well.
	Syntax: pmap <map> <TtypeLeft> <TypeRight> <valLeft> <valRight>: Prints map size, if T defined all elements or just element(s) with val(s)
	Examples:
	pmap_member m class1 member1 class2 member2 - prints class1.member1 : class2.member2
	pmap_member m class1 member1 class2 member2 lvalue - prints class1.member1 : class2.member2 where class1 == lvalue
end

# std::set and std::multiset

define pset
	if $argc == 0
		help pset
	else
		set $tree = $arg0
		set $i = 0
		set $node = $tree._M_t._M_impl._M_header._M_left
		set $end = $tree._M_t._M_impl._M_header
		set $tree_size = $tree._M_t._M_impl._M_node_count
		if $argc == 1
			printf "Set "
			whatis $tree
			printf "Use pset <variable_name> <element_type> to see the elements in the set.\n"
		end
		if $argc == 2
			while $i < $tree_size
				set $value = (void *)($node + 1)
				printf "elem[%u]: ", $i
				p *($arg1*)$value
				if $node._M_right != 0
					set $node = $node._M_right
					while $node._M_left != 0
						set $node = $node._M_left
					end
				else
					set $tmp_node = $node._M_parent
					while $node == $tmp_node._M_right
						set $node = $tmp_node
						set $tmp_node = $tmp_node._M_parent
					end
					if $node._M_right != $tmp_node
						set $node = $tmp_node
					end
				end
				set $i++
			end
		end
		if $argc == 3
			set $idx = $arg2
			set $ElementsFound = 0
			while $i < $tree_size
				set $value = (void *)($node + 1)
				if *($arg1*)$value == $idx
					printf "elem[%u]: ", $i
					p *($arg1*)$value
					set $ElementsFound++
				end
				if $node._M_right != 0
					set $node = $node._M_right
					while $node._M_left != 0
						set $node = $node._M_left
					end
				else
					set $tmp_node = $node._M_parent
					while $node == $tmp_node._M_right
						set $node = $tmp_node
						set $tmp_node = $tmp_node._M_parent
					end
					if $node._M_right != $tmp_node
						set $node = $tmp_node
					end
				end
				set $i++
			end
			printf "Number of elements found = %u\n", $ElementsFound
		end
		printf "Set size = %u\n", $tree_size
	end
end

document pset
	Prints std::set<T> or std::multiset<T> information. Works for std::multiset as well.
	Syntax: pset <set> <T> <val>: Prints set size, if T defined all elements or just element(s) having val
	Examples:
	pset s - prints set size and definition
	pset s int - prints all elements and the size of s
	pset s int 20 - prints the element(s) with value = 20 (if any) and the size of s
end

# std::dequeue

define pdequeue
	if $argc == 0
		help pdequeue
	else
		set $size = 0
		set $start_cur = $arg0._M_impl._M_start._M_cur
		set $start_last = $arg0._M_impl._M_start._M_last
		set $start_stop = $start_last
		while $start_cur != $start_stop
			p *$start_cur
			set $start_cur++
			set $size++
		end
		set $finish_first = $arg0._M_impl._M_finish._M_first
		set $finish_cur = $arg0._M_impl._M_finish._M_cur
		set $finish_last = $arg0._M_impl._M_finish._M_last
		if $finish_cur < $finish_last
			set $finish_stop = $finish_cur
		else
			set $finish_stop = $finish_last
		end
		while $finish_first != $finish_stop
			p *$finish_first
			set $finish_first++
			set $size++
		end
		printf "Dequeue size = %u\n", $size
	end
end

document pdequeue
	Prints std::dequeue<T> information.
	Syntax: pdequeue <dequeue>: Prints dequeue size, if T defined all elements
	Deque elements are listed "left to right" (left-most stands for front and right-most stands for back)
	Example:
	pdequeue d - prints all elements and size of d
end

# std::stack

define pstack
	if $argc == 0
		help pstack
	else
		set $start_cur = $arg0.c._M_impl._M_start._M_cur
		set $finish_cur = $arg0.c._M_impl._M_finish._M_cur
		set $size = $finish_cur - $start_cur
        set $i = $size - 1
        while $i >= 0
            p *($start_cur + $i)
            set $i--
        end
		printf "Stack size = %u\n", $size
	end
end

document pstack
	Prints std::stack<T> information.
	Syntax: pstack <stack>: Prints all elements and size of the stack
	Stack elements are listed "top to buttom" (top-most element is the first to come on pop)
	Example:
	pstack s - prints all elements and the size of s
end

# std::queue

define pqueue
	if $argc == 0
		help pqueue
	else
		set $start_cur = $arg0.c._M_impl._M_start._M_cur
		set $finish_cur = $arg0.c._M_impl._M_finish._M_cur
		set $size = $finish_cur - $start_cur
        set $i = 0
        while $i < $size
            p *($start_cur + $i)
            set $i++
        end
		printf "Queue size = %u\n", $size
	end
end

document pqueue
	Prints std::queue<T> information.
	Syntax: pqueue <queue>: Prints all elements and the size of the queue
	Queue elements are listed "top to bottom" (top-most element is the first to come on pop)
	Example:
	pqueue q - prints all elements and the size of q
end

# std::priority_queue

define ppqueue
	if $argc == 0
		help ppqueue
	else
		set $size = $arg0.c._M_impl._M_finish - $arg0.c._M_impl._M_start
		set $capacity = $arg0.c._M_impl._M_end_of_storage - $arg0.c._M_impl._M_start
		set $i = $size - 1
		while $i >= 0
			p *($arg0.c._M_impl._M_start + $i)
			set $i--
		end
		printf "Priority queue size = %u\n", $size
		printf "Priority queue capacity = %u\n", $capacity
	end
end

document ppqueue
	Prints std::priority_queue<T> information.
	Syntax: ppqueue <priority_queue>: Prints all elements, size and capacity of the priority_queue
	Priority_queue elements are listed "top to buttom" (top-most element is the first to come on pop)
	Example:
	ppqueue pq - prints all elements, size and capacity of pq
end

# std::bitset

define pbitset
	if $argc == 0
		help pbitset
	else
        p /t $arg0._M_w
	end
end


# std::string

define pstring
	if $argc == 0
		help pstring
	else
		printf "String \t\t\t= \"%s\"\n", $arg0._M_data()
		printf "String size/length \t= %u\n", $arg0._M_rep()._M_length
		printf "String capacity \t= %u\n", $arg0._M_rep()._M_capacity
		printf "String ref-count \t= %d\n", $arg0._M_rep()._M_refcount
	end
end



# std::wstring

define pwstring
	if $argc == 0
		help pwstring
	else
		call printf("WString \t\t= \"%ls\"\n", $arg0._M_data())
		printf "WString size/length \t= %u\n", $arg0._M_rep()._M_length
		printf "WString capacity \t= %u\n", $arg0._M_rep()._M_capacity
		printf "WString ref-count \t= %d\n", $arg0._M_rep()._M_refcount
	end
end

document pwstring
	Prints std::wstring information.
	Syntax: pwstring <wstring>
	Example:
	pwstring s - Prints content, size/length, capacity and ref-count of wstring s
end





define reg
 if ($64BITS == 1)
# 64bits stuff
    printf "  "
    echo \033[32m
    printf "RAX:"
    echo \033[0m
    printf " 0x%016lX  ", $rax
    echo \033[32m
    printf "RBX:"
    echo \033[0m
    printf " 0x%016lX  ", $rbx
    echo \033[32m
    printf "RCX:"
    echo \033[0m
    printf " 0x%016lX  ", $rcx
    echo \033[32m
    printf "RDX:"
    echo \033[0m
    printf " 0x%016lX  ", $rdx
    echo \033[1m\033[4m\033[31m
    flags
    echo \033[0m
    printf "  "
    echo \033[32m
    printf "RSI:"
    echo \033[0m
    printf " 0x%016lX  ", $rsi
    echo \033[32m
    printf "RDI:"
    echo \033[0m
    printf " 0x%016lX  ", $rdi
    echo \033[32m
    printf "RBP:"
    echo \033[0m
    printf " 0x%016lX  ", $rbp
    echo \033[32m
    printf "RSP:"
    echo \033[0m
    printf " 0x%016lX  ", $rsp
    echo \033[32m
    printf "RIP:"
    echo \033[0m
    printf " 0x%016lX\n  ", $rip
    echo \033[32m
    printf "R8 :"
    echo \033[0m
    printf " 0x%016lX  ", $r8
    echo \033[32m
    printf "R9 :"
    echo \033[0m
    printf " 0x%016lX  ", $r9
    echo \033[32m
    printf "R10:"
    echo \033[0m
    printf " 0x%016lX  ", $r10
    echo \033[32m
    printf "R11:"
    echo \033[0m
    printf " 0x%016lX  ", $r11
    echo \033[32m
    printf "R12:"
    echo \033[0m
    printf " 0x%016lX\n  ", $r12
    echo \033[32m
    printf "R13:"
    echo \033[0m
    printf " 0x%016lX  ", $r13
    echo \033[32m
    printf "R14:"
    echo \033[0m
    printf " 0x%016lX  ", $r14
    echo \033[32m
    printf "R15:"
    echo \033[0m
    printf " 0x%016lX\n  ", $r15
    echo \033[32m
    printf "CS:"
    echo \033[0m
    printf " %04X  ", $cs
    echo \033[32m
    printf "DS:"
    echo \033[0m
    printf " %04X  ", $ds
    echo \033[32m
    printf "ES:"
    echo \033[0m
    printf " %04X  ", $es
    echo \033[32m
    printf "FS:"
    echo \033[0m
    printf " %04X  ", $fs
    echo \033[32m
    printf "GS:"
    echo \033[0m
    printf " %04X  ", $gs
    echo \033[32m
    printf "SS:"
    echo \033[0m
    printf " %04X", $ss
    echo \033[0m
# 32bits stuff
 else
    printf "  "
    echo \033[32m
    printf "EAX:"
    echo \033[0m
    printf " 0x%08X  ", $eax
    echo \033[32m
    printf "EBX:"
    echo \033[0m
    printf " 0x%08X  ", $ebx
    echo \033[32m
    printf "ECX:"
    echo \033[0m
    printf " 0x%08X  ", $ecx
    echo \033[32m
    printf "EDX:"
    echo \033[0m
    printf " 0x%08X  ", $edx
    echo \033[1m\033[4m\033[31m
    flags
    echo \033[0m
    printf "  "
    echo \033[32m
    printf "ESI:"
    echo \033[0m
    printf " 0x%08X  ", $esi
    echo \033[32m
    printf "EDI:"
    echo \033[0m
    printf " 0x%08X  ", $edi
    echo \033[32m
    printf "EBP:"
    echo \033[0m
    printf " 0x%08X  ", $ebp
    echo \033[32m
    printf "ESP:"
    echo \033[0m
    printf " 0x%08X  ", $esp
    echo \033[32m
    printf "EIP:"
    echo \033[0m
    printf " 0x%08X\n  ", $eip
    echo \033[32m
    printf "CS:"
    echo \033[0m
    printf " %04X  ", $cs
    echo \033[32m
    printf "DS:"
    echo \033[0m
    printf " %04X  ", $ds
    echo \033[32m
    printf "ES:"
    echo \033[0m
    printf " %04X  ", $es
    echo \033[32m
    printf "FS:"
    echo \033[0m
    printf " %04X  ", $fs
    echo \033[32m
    printf "GS:"
    echo \033[0m
    printf " %04X  ", $gs
    echo \033[32m
    printf "SS:"
    echo \033[0m
    printf " %04X", $ss
    echo \033[0m
 end
# call smallregisters
	smallregisters
# display conditional jump routine
	if ($64BITS == 1)
	 printf "\t\t\t\t"
	end
    dumpjump
    printf "\n"
end
document reg
Print CPU registers.
end

define smallregisters
 if ($64BITS == 1)
#64bits stuff
	# from rax
	set $eax = $rax & 0xffffffff
	set $ax = $rax & 0xffff
	set $al = $ax & 0xff
	set $ah = $ax >> 8
	# from rbx
	set $bx = $rbx & 0xffff
	set $bl = $bx & 0xff
	set $bh = $bx >> 8
	# from rcx
	set $ecx = $rcx & 0xffffffff
	set $cx = $rcx & 0xffff
	set $cl = $cx & 0xff
	set $ch = $cx >> 8
	# from rdx
	set $edx = $rdx & 0xffffffff
	set $dx = $rdx & 0xffff
	set $dl = $dx & 0xff
	set $dh = $dx >> 8
	# from rsi
	set $esi = $rsi & 0xffffffff
	set $si = $rsi & 0xffff
	# from rdi
	set $edi = $rdi & 0xffffffff
	set $di = $rdi & 0xffff		
#32 bits stuff
 else
	# from eax
	set $ax = $eax & 0xffff
	set $al = $ax & 0xff
	set $ah = $ax >> 8
	# from ebx
	set $bx = $ebx & 0xffff
	set $bl = $bx & 0xff
	set $bh = $bx >> 8
	# from ecx
	set $cx = $ecx & 0xffff
	set $cl = $cx & 0xff
	set $ch = $cx >> 8
	# from edx
	set $dx = $edx & 0xffff
	set $dl = $dx & 0xff
	set $dh = $dx >> 8
	# from esi
	set $si = $esi & 0xffff
	# from edi
	set $di = $edi & 0xffff		
 end
 
end
document smallregisters
Create the 16 and 8 bit cpu registers (gdb doesn't have them by default)
And 32bits if we are dealing with 64bits binaries
end

define func
    if $argc == 0
        info functions
    end
    if $argc == 1
        info functions $arg0
    end
    if $argc > 1
        help func
    end
end
document func
Print all function names in target, or those matching REGEXP.
Usage: func <REGEXP>
end


define var
    if $argc == 0
        info variables
    end
    if $argc == 1
        info variables $arg0
    end
    if $argc > 1
        help var
    end
end
document var
Print all global and static variable names (symbols), or those matching REGEXP.
Usage: var <REGEXP>
end


define lib
    info sharedlibrary
end
document lib
Print shared libraries linked to target.
end


define sig
    if $argc == 0
        info signals
    end
    if $argc == 1
        info signals $arg0
    end
    if $argc > 1
        help sig
    end
end
document sig
Print what debugger does when program gets various signals.
Specify a SIGNAL as argument to print info on that signal only.
Usage: sig <SIGNAL>
end


define threads
    info threads
end
document threads
Print threads in target.
end

define ascii_char
    if $argc != 1
        help ascii_char
    else
        # thanks elaine :)
        set $_c = *(unsigned char *)($arg0)
        if ($_c < 0x20 || $_c > 0x7E)
            printf "."
        else
            printf "%c", $_c
        end
    end
end
document ascii_char
Print ASCII value of byte at address ADDR.
Print "." if the value is unprintable.
Usage: ascii_char ADDR
end


define hex_quad
    if $argc != 1
        help hex_quad
    else
        printf "%02X %02X %02X %02X %02X %02X %02X %02X", \
               *(unsigned char*)($arg0), *(unsigned char*)($arg0 + 1),     \
               *(unsigned char*)($arg0 + 2), *(unsigned char*)($arg0 + 3), \
               *(unsigned char*)($arg0 + 4), *(unsigned char*)($arg0 + 5), \
               *(unsigned char*)($arg0 + 6), *(unsigned char*)($arg0 + 7)
    end
end
document hex_quad
Print eight hexadecimal bytes starting at address ADDR.
Usage: hex_quad ADDR
end

define hexdump
    if $argc != 1
        help hexdump
    else
        echo \033[1m
        if ($64BITS == 1)
         printf "0x%016lX : ", $arg0
        else
         printf "0x%08X : ", $arg0
        end
        echo \033[0m
        hex_quad $arg0
        echo \033[1m
        printf " - "
        echo \033[0m
        hex_quad $arg0+8
        printf " "
        echo \033[1m
        ascii_char $arg0+0x0
        ascii_char $arg0+0x1
        ascii_char $arg0+0x2
        ascii_char $arg0+0x3
        ascii_char $arg0+0x4
        ascii_char $arg0+0x5
        ascii_char $arg0+0x6
        ascii_char $arg0+0x7
        ascii_char $arg0+0x8
        ascii_char $arg0+0x9
        ascii_char $arg0+0xA
        ascii_char $arg0+0xB
        ascii_char $arg0+0xC
        ascii_char $arg0+0xD
        ascii_char $arg0+0xE
        ascii_char $arg0+0xF
        echo \033[0m
        printf "\n"
    end
end
document hexdump
Display a 16-byte hex/ASCII dump of memory at address ADDR.
Usage: hexdump ADDR
end


define ddump
    if $argc != 1
        help ddump
    else
        echo \033[34m
        if ($64BITS == 1)
         printf "[0x%04X:0x%016lX]", $ds, $data_addr
        else
         printf "[0x%04X:0x%08X]", $ds, $data_addr
        end
	echo \033[34m
	printf "------------------------"
    printf "-------------------------------"
    if ($64BITS == 1)
     printf "-------------------------------------"
	end

	echo \033[1;34m
	printf "[data]\n"
        echo \033[0m
        set $_count = 0
        while ($_count < $arg0)
            set $_i = ($_count * 0x10)
            hexdump $data_addr+$_i
            set $_count++
        end
    end
end
document ddump
Display NUM lines of hexdump for address in $data_addr global variable.
Usage: ddump NUM
end


define dd
    if $argc != 1
        help dd
    else
        if ((($arg0 >> 0x18) == 0x40) || (($arg0 >> 0x18) == 0x08) || (($arg0 >> 0x18) == 0xBF))
            set $data_addr = $arg0
            ddump 0x10
        else
            printf "Invalid address: %08X\n", $arg0
        end
    end
end
document dd
Display 16 lines of a hex dump of address starting at ADDR.
Usage: dd ADDR
end



define datawin
 if ($64BITS == 1)
    if ((($rsi >> 0x18) == 0x40) || (($rsi >> 0x18) == 0x08) || (($rsi >> 0x18) == 0xBF))
        set $data_addr = $rsi
    else
        if ((($rdi >> 0x18) == 0x40) || (($rdi >> 0x18) == 0x08) || (($rdi >> 0x18) == 0xBF))
            set $data_addr = $rdi
        else
            if ((($rax >> 0x18) == 0x40) || (($rax >> 0x18) == 0x08) || (($rax >> 0x18) == 0xBF))
                set $data_addr = $rax
            else
                set $data_addr = $rsp
            end
        end
    end

 else
    if ((($esi >> 0x18) == 0x40) || (($esi >> 0x18) == 0x08) || (($esi >> 0x18) == 0xBF))
        set $data_addr = $esi
    else
        if ((($edi >> 0x18) == 0x40) || (($edi >> 0x18) == 0x08) || (($edi >> 0x18) == 0xBF))
            set $data_addr = $edi
        else
            if ((($eax >> 0x18) == 0x40) || (($eax >> 0x18) == 0x08) || (($eax >> 0x18) == 0xBF))
                set $data_addr = $eax
            else
                set $data_addr = $esp
            end
        end
    end
 end
    ddump $CONTEXTSIZE_DATA
end
document datawin
Display valid address from one register in data window.
Registers to choose are: esi, edi, eax, or esp.
end

define dumpjump
## grab the first two bytes from the instruction so we can determine the jump instruction
 set $_byte1 = *(unsigned char *)$pc
 set $_byte2 = *(unsigned char *)($pc+1)
## and now check what kind of jump we have (in case it's a jump instruction)
## I changed the flags routine to save the flag into a variable, so we don't need to repeat the process :) (search for "define flags")

## opcode 0x77: JA, JNBE (jump if CF=0 and ZF=0)
## opcode 0x0F87: JNBE, JA
 if ( ($_byte1 == 0x77) || ($_byte1 == 0x0F && $_byte2 == 0x87) )
 	# cf=0 and zf=0
 	if ($_cf_flag == 0 && $_zf_flag == 0)
		echo \033[31m
   		printf "  Jump is taken (c=0 and z=0)"
  	else
	# cf != 0 or zf != 0
   		echo \033[31m
   		printf "  Jump is NOT taken (c!=0 or z!=0)"
  	end
 end

## opcode 0x73: JAE, JNB, JNC (jump if CF=0)
## opcode 0x0F83: JNC, JNB, JAE (jump if CF=0)
 if ( ($_byte1 == 0x73) || ($_byte1 == 0x0F && $_byte2 == 0x83) )
 	# cf=0
 	if ($_cf_flag == 0)
		echo \033[31m
   		printf "  Jump is taken (c=0)"
  	else
	# cf != 0
   		echo \033[31m
   		printf "  Jump is NOT taken (c!=0)"
  	end
 end

## opcode 0x72: JB, JC, JNAE (jump if CF=1)
## opcode 0x0F82: JNAE, JB, JC
 if ( ($_byte1 == 0x72) || ($_byte1 == 0x0F && $_byte2 == 0x82) )
 	# cf=1
 	if ($_cf_flag == 1)
		echo \033[31m
   		printf "  Jump is taken (c=1)"
  	else
	# cf != 1
   		echo \033[31m
   		printf "  Jump is NOT taken (c!=1)"
  	end
 end

## opcode 0x76: JBE, JNA (jump if CF=1 or ZF=1)
## opcode 0x0F86: JBE, JNA
 if ( ($_byte1 == 0x76) || ($_byte1 == 0x0F && $_byte2 == 0x86) )
 	# cf=1 or zf=1
 	if (($_cf_flag == 1) || ($_zf_flag == 1))
		echo \033[31m
   		printf "  Jump is taken (c=1 or z=1)"
  	else
	# cf != 1 or zf != 1
   		echo \033[31m
   		printf "  Jump is NOT taken (c!=1 or z!=1)"
  	end
 end

## opcode 0xE3: JCXZ, JECXZ, JRCXZ (jump if CX=0 or ECX=0 or RCX=0)
 if ($_byte1 == 0xE3)
 	# cx=0 or ecx=0
 	if (($ecx == 0) || ($cx == 0))
		echo \033[31m
   		printf "  Jump is taken (cx=0 or ecx=0)"
  	else
	#
   		echo \033[31m
   		printf "  Jump is NOT taken (cx!=0 or ecx!=0)"
  	end
 end

## opcode 0x74: JE, JZ (jump if ZF=1)
## opcode 0x0F84: JZ, JE, JZ (jump if ZF=1)
 if ( ($_byte1 == 0x74) || ($_byte1 == 0x0F && $_byte2 == 0x84) )
 # ZF = 1
  	if ($_zf_flag == 1)
   		echo \033[31m
   		printf "  Jump is taken (z=1)"
  	else
 # ZF = 0
   		echo \033[31m
   		printf "  Jump is NOT taken (z!=1)"
  	end
 end

## opcode 0x7F: JG, JNLE (jump if ZF=0 and SF=OF)
## opcode 0x0F8F: JNLE, JG (jump if ZF=0 and SF=OF)
 if ( ($_byte1 == 0x7F) || ($_byte1 == 0x0F && $_byte2 == 0x8F) )
 # zf = 0 and sf = of
  	if (($_zf_flag == 0) && ($_sf_flag == $_of_flag))
   		echo \033[31m
   		printf "  Jump is taken (z=0 and s=o)"
  	else
 #
   		echo \033[31m
   		printf "  Jump is NOT taken (z!=0 or s!=o)"
  	end
 end

## opcode 0x7D: JGE, JNL (jump if SF=OF)
## opcode 0x0F8D: JNL, JGE (jump if SF=OF)
 if ( ($_byte1 == 0x7D) || ($_byte1 == 0x0F && $_byte2 == 0x8D) )
 # sf = of
  	if ($_sf_flag == $_of_flag)
   		echo \033[31m
   		printf "  Jump is taken (s=o)"
  	else
 #
   		echo \033[31m
   		printf "  Jump is NOT taken (s!=o)"
  	end
 end

## opcode: 0x7C: JL, JNGE (jump if SF != OF)
## opcode: 0x0F8C: JNGE, JL (jump if SF != OF)
 if ( ($_byte1 == 0x7C) || ($_byte1 == 0x0F && $_byte2 == 0x8C) )
 # sf != of
  	if ($_sf_flag != $_of_flag)
   		echo \033[31m
   		printf "  Jump is taken (s!=o)"
  	else
 #
   		echo \033[31m
   		printf "  Jump is NOT taken (s=o)"
  	end
 end

## opcode 0x7E: JLE, JNG (jump if ZF = 1 or SF != OF)
## opcode 0x0F8E: JNG, JLE (jump if ZF = 1 or SF != OF)
 if ( ($_byte1 == 0x7E) || ($_byte1 == 0x0F && $_byte2 == 0x8E) )
 # zf = 1 or sf != of
  	if (($_zf_flag == 1) || ($_sf_flag != $_of_flag))
   		echo \033[31m
   		printf "  Jump is taken (zf=1 or sf!=of)"
  	else
 #
   		echo \033[31m
   		printf "  Jump is NOT taken (zf!=1 or sf=of)"
  	end
 end

## opcode 0x75: JNE, JNZ (jump if ZF = 0)
## opcode 0x0F85: JNE, JNZ (jump if ZF = 0)
 if ( ($_byte1 == 0x75) || ($_byte1 == 0x0F && $_byte2 == 0x85) )
 # ZF = 0
  	if ($_zf_flag == 0)
   		echo \033[31m
   		printf "  Jump is taken (z=0)"
  	else
 # ZF = 1
   		echo \033[31m
   		printf "  Jump is NOT taken (z!=0)"
  	end
 end

## opcode 0x71: JNO (OF = 0)
## opcode 0x0F81: JNO (OF = 0)
 if ( ($_byte1 == 0x71) || ($_byte1 == 0x0F && $_byte2 == 0x81) )
 # OF = 0
	if ($_of_flag == 0)
   		echo \033[31m
   		printf "  Jump is taken (o=0)"
	else
 # OF != 0
   		echo \033[31m
   		printf "  Jump is NOT taken (o!=0)"
  	end
 end

## opcode 0x7B: JNP, JPO (jump if PF = 0)
## opcode 0x0F8B: JPO (jump if PF = 0)
 if ( ($_byte1 == 0x7B) || ($_byte1 == 0x0F && $_byte2 == 0x8B) )
 # PF = 0
  	if ($_pf_flag == 0)
   		echo \033[31m
   		printf "  Jump is NOT taken (p=0)"
  	else
 # PF != 0
   		echo \033[31m
   		printf "  Jump is taken (p!=0)"
  	end
 end

## opcode 0x79: JNS (jump if SF = 0)
## opcode 0x0F89: JNS (jump if SF = 0)
 if ( ($_byte1 == 0x79) || ($_byte1 == 0x0F && $_byte2 == 0x89) )
 # SF = 0
  	if ($_sf_flag == 0)
   		echo \033[31m
   		printf "  Jump is taken (s=0)"
  	else
 # SF != 0
   		echo \033[31m
   		printf "  Jump is NOT taken (s!=0)"
  	end
 end

## opcode 0x70: JO (jump if OF=1)
## opcode 0x0F80: JO (jump if OF=1)
 if ( ($_byte1 == 0x70) || ($_byte1 == 0x0F && $_byte2 == 0x80) )
 # OF = 1
	if ($_of_flag == 1)
		echo \033[31m
   		printf "  Jump is taken (o=1)"
  	else
 # OF != 1
   		echo \033[31m
   		printf "  Jump is NOT taken (o!=1)"
  	end
 end

## opcode 0x7A: JP, JPE (jump if PF=1)
## opcode 0x0F8A: JP, JPE (jump if PF=1)
 if ( ($_byte1 == 0x7A) || ($_byte1 == 0x0F && $_byte2 == 0x8A) )
 # PF = 1
  	if ($_pf_flag == 1)
   		echo \033[31m
   		printf "  Jump is taken (p=1)"
  	else
 # PF = 0
   		echo \033[31m
   		printf "  Jump is NOT taken (p!=1)"
  	end
 end

## opcode 0x78: JS (jump if SF=1)
## opcode 0x0F88: JS (jump if SF=1)
 if ( ($_byte1 == 0x78) || ($_byte1 == 0x0F && $_byte2 == 0x88) )
 # SF = 1
	if ($_sf_flag == 1)
   		echo \033[31m
   		printf "  Jump is taken (s=1)"
  	else
 # SF != 1
   		echo \033[31m
   		printf "  Jump is NOT taken (s!=1)"
  	end
 end

# end of dumpjump function
end
document dumpjump
Display if conditional jump will be taken or not
end

define cfc
    if ($eflags & 1)
        set $eflags = $eflags&~0x1
    else
        set $eflags = $eflags|0x1
    end
end
document cfc
Change Carry Flag.
end


define cfp
    if (($eflags >> 2) & 1)
        set $eflags = $eflags&~0x4
    else
        set $eflags = $eflags|0x4
    end
end
document cfp
Change Parity Flag.
end


define cfa
    if (($eflags >> 4) & 1)
        set $eflags = $eflags&~0x10
    else
        set $eflags = $eflags|0x10
    end
end
document cfa
Change Auxiliary Carry Flag.
end


define cfz
    if (($eflags >> 6) & 1)
        set $eflags = $eflags&~0x40
    else
        set $eflags = $eflags|0x40
    end
end
document cfz
Change Zero Flag.
end


define cfs
    if (($eflags >> 7) & 1)
        set $eflags = $eflags&~0x80
    else
        set $eflags = $eflags|0x80
    end
end
document cfs
Change Sign Flag.
end


define cft
    if (($eflags >>8) & 1)
        set $eflags = $eflags&~0x100
    else
        set $eflags = $eflags|0x100
    end
end
document cft
Change Trap Flag.
end


define cfi
    if (($eflags >> 9) & 1)
        set $eflags = $eflags&~0x200
    else
        set $eflags = $eflags|0x200
    end
end
document cfi
Change Interrupt Flag.
Only privileged applications (usually the OS kernel) may modify IF.
This only applies to protected mode (real mode code may always modify IF).
end


define cfd
    if (($eflags >>0xA) & 1)
        set $eflags = $eflags&~0x400
    else
        set $eflags = $eflags|0x400
    end
end
document cfd
Change Direction Flag.
end


define cfo
    if (($eflags >> 0xB) & 1)
        set $eflags = $eflags&~0x800
    else
        set $eflags = $eflags|0x800
    end
end
document cfo
Change Overflow Flag.
end



define null
    if ( $argc >2 || $argc == 0)
        help null
    end

    if ($argc == 1)
	set *(unsigned char *)$arg0 = 0
    else
	set $addr = $arg0
	while ($addr < $arg1)
	        set *(unsigned char *)$addr = 0
		set $addr = $addr +1
	end
    end
end
document null
Usage: null ADDR1 [ADDR2]
Patch a single byte at address ADDR1 to NULL (0x00), or a series of bytes between ADDR1 and ADDR2.

end


define int3
    if $argc != 1
        help int3
    else
        set *(unsigned char *)$arg0 = 0xCC
    end
end
document int3
Patch byte at address ADDR to an INT3 (0xCC) instruction.
Usage: int3 ADDR
end


define print_insn_type
    if $argc != 1
        help print_insn_type
    else
        if ($arg0 < 0 || $arg0 > 5)
            printf "UNDEFINED/WRONG VALUE"
        end
        if ($arg0 == 0)
            printf "UNKNOWN"
        end
        if ($arg0 == 1)
            printf "JMP"
        end
        if ($arg0 == 2)
            printf "JCC"
        end
        if ($arg0 == 3)
            printf "CALL"
        end
        if ($arg0 == 4)
            printf "RET"
        end
        if ($arg0 == 5)
            printf "INT"
        end
    end
end
document print_insn_type
Print human-readable mnemonic for the instruction type (usually $INSN_TYPE).
Usage: print_insn_type INSN_TYPE_NUMBER
end


define get_insn_type
    if $argc != 1
        help get_insn_type
    else
        set $INSN_TYPE = 0
        set $_byte1 = *(unsigned char *)$arg0
        if ($_byte1 == 0x9A || $_byte1 == 0xE8)
            # "call"
            set $INSN_TYPE = 3
        end
        if ($_byte1 >= 0xE9 && $_byte1 <= 0xEB)
            # "jmp"
            set $INSN_TYPE = 1
        end
        if ($_byte1 >= 0x70 && $_byte1 <= 0x7F)
            # "jcc"
            set $INSN_TYPE = 2
        end
        if ($_byte1 >= 0xE0 && $_byte1 <= 0xE3 )
            # "jcc"
            set $INSN_TYPE = 2
        end
        if ($_byte1 == 0xC2 || $_byte1 == 0xC3 || $_byte1 == 0xCA || \
            $_byte1 == 0xCB || $_byte1 == 0xCF)
            # "ret"
            set $INSN_TYPE = 4
        end
        if ($_byte1 >= 0xCC && $_byte1 <= 0xCE)
            # "int"
            set $INSN_TYPE = 5
        end
        if ($_byte1 == 0x0F )
            # two-byte opcode
            set $_byte2 = *(unsigned char *)($arg0 + 1)
            if ($_byte2 >= 0x80 && $_byte2 <= 0x8F)
                # "jcc"
                set $INSN_TYPE = 2
            end
        end
        if ($_byte1 == 0xFF)
            # opcode extension
            set $_byte2 = *(unsigned char *)($arg0 + 1)
            set $_opext = ($_byte2 & 0x38)
            if ($_opext == 0x10 || $_opext == 0x18)
                # "call"
                set $INSN_TYPE = 3
            end
            if ($_opext == 0x20 || $_opext == 0x28)
                # "jmp"
                set $INSN_TYPE = 1
            end
        end
    end
end
document get_insn_type
Recognize instruction type at address ADDR.
Take address ADDR and set the global $INSN_TYPE variable to
0, 1, 2, 3, 4, 5 if the instruction at that address is
unknown, a jump, a conditional jump, a call, a return, or an interrupt.
Usage: get_insn_type ADDR
end


define step_to_call
    set $_saved_ctx = $SHOW_CONTEXT
    set $SHOW_CONTEXT = 0
    set $SHOW_NEST_INSN = 0

    set logging file /dev/null
    set logging redirect on
    set logging on

    set $_cont = 1
    while ($_cont > 0)
        stepi
        get_insn_type $pc
        if ($INSN_TYPE == 3)
            set $_cont = 0
        end
    end

    set logging off

    if ($_saved_ctx > 0)
        context
    end

    set $SHOW_CONTEXT = $_saved_ctx
    set $SHOW_NEST_INSN = 0

    set logging file ~/gdb.txt
    set logging redirect off
    set logging on

    printf "step_to_call command stopped at:\n  "
    x/i $pc
    printf "\n"
    set logging off

end
document step_to_call
Single step until a call instruction is found.
Stop before the call is taken.
Log is written into the file ~/gdb.txt.
end


define trace_calls

    printf "Tracing...please wait...\n"

    set $_saved_ctx = $SHOW_CONTEXT
    set $SHOW_CONTEXT = 0
    set $SHOW_NEST_INSN = 0
    set $_nest = 1
    set listsize 0

    set logging overwrite on
    set logging file ~/gdb_trace_calls.txt
    set logging on
    set logging off
    set logging overwrite off

    while ($_nest > 0)
        get_insn_type $pc
        # handle nesting
        if ($INSN_TYPE == 3)
            set $_nest = $_nest + 1
        else
            if ($INSN_TYPE == 4)
                set $_nest = $_nest - 1
            end
        end
        # if a call, print it
        if ($INSN_TYPE == 3)
            set logging file ~/gdb_trace_calls.txt
            set logging redirect off
            set logging on

            set $x = $_nest - 2
            while ($x > 0)
                printf "\t"
                set $x = $x - 1
            end
            x/i $pc
        end

        set logging off
        set logging file /dev/null
        set logging redirect on
        set logging on
        stepi
        set logging redirect off
        set logging off
    end

    set $SHOW_CONTEXT = $_saved_ctx
    set $SHOW_NEST_INSN = 0

    printf "Done, check ~/gdb_trace_calls.txt\n"
end
document trace_calls
Create a runtime trace of the calls made by target.
Log overwrites(!) the file ~/gdb_trace_calls.txt.
end


define trace_run

    printf "Tracing...please wait...\n"

    set $_saved_ctx = $SHOW_CONTEXT
    set $SHOW_CONTEXT = 0
    set $SHOW_NEST_INSN = 1
    set logging overwrite on
    set logging file ~/gdb_trace_run.txt
    set logging redirect on
    set logging on
    set $_nest = 1

    while ( $_nest > 0 )

        get_insn_type $pc
        # jmp, jcc, or cll
        if ($INSN_TYPE == 3)
            set $_nest = $_nest + 1
        else
            # ret
            if ($INSN_TYPE == 4)
                set $_nest = $_nest - 1
            end
        end
        stepi
    end

    printf "\n"

    set $SHOW_CONTEXT = $_saved_ctx
    set $SHOW_NEST_INSN = 0
    set logging redirect off
    set logging off

    # clean up trace file
    shell  grep -v ' at ' ~/gdb_trace_run.txt > ~/gdb_trace_run.1
    shell  grep -v ' in ' ~/gdb_trace_run.1 > ~/gdb_trace_run.txt
    shell  rm -f ~/gdb_trace_run.1
    printf "Done, check ~/gdb_trace_run.txt\n"
end
document trace_run
Create a runtime trace of target.
Log overwrites(!) the file ~/gdb_trace_run.txt.
end



define tips
    printf "Tip Topic Commands:\n"
    printf "\ttip_display : Automatically display values on each break\n"
    printf "\ttip_patch   : Patching binaries\n"
    printf "\ttip_strip   : Dealing with stripped binaries\n"
    printf "\ttip_syntax  : AT&T vs Intel syntax\n"
end
document tips
Provide a list of tips from users on various topics.
end


define tip_patch
    printf "\n"
    printf "                   PATCHING MEMORY\n"
    printf "Any address can be patched using the 'set' command:\n"
    printf "\t`set ADDR = VALUE` \te.g. `set *0x8049D6E = 0x90`\n"
    printf "\n"
    printf "                 PATCHING BINARY FILES\n"
    printf "Use `set write` in order to patch the target executable\n"
    printf "directly, instead of just patching memory\n"
    printf "\t`set write on` \t`set write off`\n"
    printf "Note that this means any patches to the code or data segments\n"
    printf "will be written to the executable file\n"
    printf "When either of these commands has been issued,\n"
    printf "the file must be reloaded.\n"
    printf "\n"
end
document tip_patch
Tips on patching memory and binary files.
end


define tip_strip
    printf "\n"
    printf "             STOPPING BINARIES AT ENTRY POINT\n"
    printf "Stripped binaries have no symbols, and are therefore tough to\n"
    printf "start automatically. To debug a stripped binary, use\n"
    printf "\tinfo file\n"
    printf "to get the entry point of the file\n"
    printf "The first few lines of output will look like this:\n"
    printf "\tSymbols from '/tmp/a.out'\n"
    printf "\tLocal exec file:\n"
    printf "\t        `/tmp/a.out', file type elf32-i386.\n"
    printf "\t        Entry point: 0x80482e0\n"
    printf "Use this entry point to set an entry point:\n"
    printf "\t`tbreak *0x80482e0`\n"
    printf "The breakpoint will delete itself after the program stops as\n"
    printf "the entry point\n"
    printf "\n"
end
document tip_strip
Tips on dealing with stripped binaries.
end


define tip_syntax
    printf "\n"
    printf "\t    INTEL SYNTAX                        AT&T SYNTAX\n"
    printf "\tmnemonic dest, src, imm            mnemonic src, dest, imm\n" 
    printf "\t[base+index*scale+disp]            disp(base, index, scale)\n"
    printf "\tregister:      eax                 register:      %%eax\n"
    printf "\timmediate:     0xFF                immediate:     $0xFF\n"
    printf "\tdereference:   [addr]              dereference:   addr(,1)\n"
    printf "\tabsolute addr: addr                absolute addr: *addr\n"
    printf "\tbyte insn:     mov byte ptr        byte insn:     movb\n"
    printf "\tword insn:     mov word ptr        word insn:     movw\n"
    printf "\tdword insn:    mov dword ptr       dword insn:    movd\n"
    printf "\tfar call:      call far            far call:      lcall\n"
    printf "\tfar jump:      jmp far             far jump:      ljmp\n"
    printf "\n"
    printf "Note that order of operands in reversed, and that AT&T syntax\n"
    printf "requires that all instructions referencing memory operands \n"
    printf "use an operand size suffix (b, w, d, q)\n"
    printf "\n"
end
document tip_syntax
Summary of Intel and AT&T syntax differences.
end


define tip_display
    printf "\n"
    printf "Any expression can be set to automatically be displayed every time\n"
    printf "the target stops. The commands for this are:\n"
    printf "\t`display expr'     : automatically display expression 'expr'\n"
    printf "\t`display'          : show all displayed expressions\n"
    printf "\t`undisplay num'    : turn off autodisplay for expression # 'num'\n"
    printf "Examples:\n"
    printf "\t`display/x *(int *)$esp`      : print top of stack\n"
    printf "\t`display/x *(int *)($ebp+8)`  : print first parameter\n"
    printf "\t`display (char *)$esi`        : print source string\n"
    printf "\t`display (char *)$edi`        : print destination string\n"
    printf "\n"
end
document tip_display
Tips on automatically displaying values when a program stops.
end

# bunch of semi-useless commands

# enable and disable shortcuts for stop-on-solib-events fantastic trick!
define enablesolib
	set stop-on-solib-events 1
end
document enablesolib
Shortcut to enable stop-on-solib-events trick!
end

define disablesolib
	set stop-on-solib-events 0
end
document disablesolib
Shortcut to disable stop-on-solib-events trick!
end

# enable commands for different displays
define enableobjectivec
	set $SHOWOBJECTIVEC = 1
end
document enableobjectivec
Enable display of objective-c information in the context window
end

define enablecpuregisters
	set $SHOWCPUREGISTERS = 1
end
document enablecpuregisters
Enable display of cpu registers in the context window
end

define enablestack
	set $SHOWSTACK = 1
end
document enablestack
Enable display of stack in the context window
end

define enabledatawin
	set $SHOWDATAWIN = 1
end
document enabledatawin
Enable display of data window in the context window
end

# disable commands for different displays
define disableobjectivec
	set $SHOWOBJECTIVEC = 0
end
document disableobjectivec
Disable display of objective-c information in the context window
end

define disablecpuregisters
	set $SHOWCPUREGISTERS = 0
end
document disablecpuregisters
Disable display of cpu registers in the context window
end

define disablestack
	set $SHOWSTACK = 0
end
document disablestack
Disable display of stack information in the context window
end

define disabledatawin
	set $SHOWDATAWIN = 0
end
document disabledatawin
Disable display of data window in the context window
end

define 32bits
	set $64BITS = 0
end
document 32bits
Set gdb to work with 32bits binaries
end

define 64bits
	set $64BITS = 1
end
document 64bits
Set gdb to work with 64bits binaries
end


define stack
    if $argc == 0
        info stack
    end
    if $argc == 1
        info stack $arg0
    end
    if $argc > 1
        help stack
    end
end
document stack
Syntax: stack <COUNT>
| Print backtrace of the call stack, or innermost COUNT frames.
end





# Start ------------------------------------------------------------------------

python Dashboard.start()

# Modified by @JpUsefRye
