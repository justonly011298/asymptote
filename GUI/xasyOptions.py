#!/usr/bin/env python
###########################################################################
#
# xasyOptions provides a mechanism for storing and restoring a user's
# preferences.
#
#
# Author: Orest Shardt
# Created: June 29, 2007
#
###########################################################################

import json
import sys
import os

try:
    import cson
except ModuleNotFoundError:
    cson = None

try:
    import yaml
except ModuleNotFoundError:
    yaml = None


class xasyOptions:
    defaultOptionsTemplate = {
        '_comment': 'Note: *ASYPATH will be replaced with the path to Asymptote file.',

        'externalEditor': '',
        'asyPath': 'asy',
        'showDebug': False,
        'defaultPenOptions': '',
        'defaultPenColor': '#000000',
        'defaultPenWidth': 1.0,
        'groupObjDefault': False,
        'enableImmediatePreview': True,
        'useDegrees': False,
        'terminalFont': 'Courier',
        'terminalFontSize': 10,
        'defaultShowAxes': True,
        'defaultShowGrid': False,
        'defaultGridSnap': False,
        'drawSelectedOnTop': True,

        '_GRID_COMMANDS': 'Grid Commands.',
        'gridMajorAxesColor': '#000000',
        'gridMinorAxesColor': '#AAAAAA',
        'gridMajorAxesSpacing': 100,
        'gridMinorAxesCount': 9,

        'debugMode': True
    }

    @classmethod
    def defaultOptions(cls):
        opt = cls.defaultOptionsTemplate.copy()
        if os.name == 'nt':
            opt['externalEditor'] = "notepad.exe *ASYPATH"
        else:
            opt['externalEditor'] = "emacs *ASYPATH"
        return opt

    @classmethod
    def settingsFileLocation(cls):
        folder = os.path.expanduser("~/.asy/")

        searchOrder = ['.cson', '.yaml', '.json', '']

        searchIndex = 0
        found = False
        currentFile = ''
        while searchIndex < len(searchOrder) and not found:
            currentFile = os.path.join(folder, "xasyconf" + searchOrder[searchIndex])
            if os.path.isfile(currentFile):
                found = True
            searchIndex += 1
        
        if found:
            return os.path.normcase(currentFile)
        else:
            return None


    def __getitem__(self, item):
        return self.options[item]

    def __setitem__(self, key, value):
        self.options[key] = value

    def __init__(self):
        self.options = xasyOptions.defaultOptions()
        self.load()

    def load(self):
        fileName = xasyOptions.settingsFileLocation()
        if not os.path.exists(fileName):
            # make folder
            thedir = os.path.dirname(fileName)
            if not os.path.exists(thedir):
                os.makedirs(thedir)
            if not os.path.isdir(thedir):
                raise Exception("Configuration folder path does not point to a folder")
            self.setDefaults()
        try:
            with open(fileName, 'r') as f:
                ext = os.path.splitext(fileName)[1]
                if ext == '.cson':
                    if cson is None:
                        raise ModuleNotFoundError
                    newOptions = cson.loads(f.read())
                elif ext in {'.yml', '.yaml'}:
                    if yaml is None:
                        raise ModuleNotFoundError
                    newOptions = yaml.load(f)
                else:
                    newOptions = json.loads(f.read())
        except (IOError, ModuleNotFoundError):
            self.setDefaults()
        else:
            for key in self.options.keys():
                if key in newOptions:
                    assert isinstance(newOptions[key], type(self.options[key]))
                else:
                    newOptions[key] = self.options[key]
            self.options = newOptions

    def setDefaults(self):
        self.options = xasyOptions.defaultOptions()
        if sys.platform[:3] == 'win':  # for windows, wince, win32, etc
            # setAsyPathFromWindowsRegistry()
            pass
        # self.save()

# TODO: Figure out how to merge this back.
"""
def setAsyPathFromWindowsRegistry():
    if os.name == 'nt':
        import _winreg as registry
        # test both registry locations
        try:
            key = registry.OpenKey(registry.HKEY_LOCAL_MACHINE,
                                   "Software\\Microsoft\\Windows\\CurrentVersion\\App Paths\\Asymptote")
            options['asyPath'] = registry.QueryValueEx(key, "Path")[0] + "\\asy.exe"
            registry.CloseKey(key)
        except:
            key = registry.OpenKey(registry.HKEY_LOCAL_MACHINE,
                                   "Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\Asymptote")
            options['asyPath'] = registry.QueryValueEx(key, "InstallLocation")[0] + "\\asy.exe"
            registry.CloseKey(key)
"""
