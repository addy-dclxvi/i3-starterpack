#!/usr/bin/env python
# 
# Print i3 workspaces on every change.
# 
# Format: 
#   For every workspace (x = workspace name)
#       - "FOCx" -> Focused workspace
#       - "INAx" -> Inactive workspace
#       - "ACTx" -> Ative workspace
#       - "URGx" -> Urgent workspace
#
# Uses i3py.py -> https://github.com/ziberna/i3-py
# Based in wsbar.py en examples dir
#
# 16 feb 2015 - Electro7


import sys
import time
import subprocess

import i3

class State(object):
    # workspace states
    focused = 'FOC'
    active = 'ACT'
    inactive = 'INA'
    urgent = 'URG'
    
    def get_state(self, workspace, output):
        if workspace['focused']:
            if output['current_workspace'] == workspace['name']:
                return self.focused
            else:
                return self.active
        if workspace['urgent']:
            return self.urgent
        else:
            return self.inactive


class i3ws(object):
    ws_format = '%s%s '
    end_format = 'WSP%s'
    state = State()
    
    def __init__(self, state=None):
        if state:
            self.state = state
        # socket
        self.socket = i3.Socket()
        # Output to console
        workspaces = self.socket.get('get_workspaces')
        outputs = self.socket.get('get_outputs')
        self.display(self.format(workspaces, outputs))
        # Subscribe to an event
        callback = lambda data, event, _: self.change(data, event)
        self.subscription = i3.Subscription(callback, 'workspace')
    
    def change(self, event, workspaces):
        # Receives event and workspace data
        if 'change' in event:
            outputs = self.socket.get('get_outputs')
            text = self.format(workspaces, outputs)
            self.display(text)
    
    def format(self, workspaces, outputs):
        # Formats the text according to the workspace data given.
        out = '' 
        for workspace in workspaces:
            output = None
            for output_ in outputs:
                if output_['name'] == workspace['output']:
                    output = output_
                    break
            if not output:
                continue
            st = self.state.get_state(workspace, output)
            name = workspace['name']
            item= self.ws_format % (st, name)
            out += item
        return self.end_format % out
    
    def display(self, text):
        # Displays the text in stout
        print(text)
        sys.stdout.flush()
    
    def quit(self):
        # Quits the i3ws; closes the subscription and terminates
        self.subscription.close()

if __name__ == '__main__':
    ws = i3ws()
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        print('')  # force new line
    finally:
        ws.quit()
