"""Local Tk tray panel. Credentials remain in the separate DPAPI editor."""
import ctypes
from ctypes import wintypes
from pathlib import Path
import tkinter as tk

STATE = str(Path(__file__).resolve().parent / 'State' / 'watcher.ini')
kernel = ctypes.WinDLL('kernel32', use_last_error=True)
kernel.GetPrivateProfileStringW.argtypes = [wintypes.LPCWSTR] * 3 + [wintypes.LPWSTR, wintypes.DWORD, wintypes.LPCWSTR]
kernel.WritePrivateProfileStringW.argtypes = [wintypes.LPCWSTR] * 4
BG, PANEL, FG, MUTED, PURPLE = '#17121f', '#261c33', '#f5f0fa', '#c1b5ce', '#8f5bc7'


def read(section, key, default=''):
    buf = ctypes.create_unicode_buffer(512)
    kernel.GetPrivateProfileStringW(section, key, default, buf, len(buf), STATE)
    return buf.value


def write(section, key, value):
    if not kernel.WritePrivateProfileStringW(section, key, value, STATE):
        raise ctypes.WinError(ctypes.get_last_error())


class Menu:
    def __init__(self):
        ctypes.windll.shell32.SetCurrentProcessExplicitAppUserModelID('NYU.Synchronization')
        self.root = tk.Tk()
        self.root.title('NYU Sync')
        self.root.iconbitmap(str(Path(__file__).with_name('NYUSynchronization.ico')))
        self.root.configure(bg=BG)
        self.root.resizable(False, False)
        self.root.attributes('-topmost', True)
        self.root.bind('<Escape>', lambda _: self.root.destroy())
        frame = tk.Frame(self.root, bg=BG, padx=20, pady=16)
        frame.pack(fill='both', expand=True)
        tk.Label(frame, text='NYU Sync', bg=BG, fg=FG,
                 font=('Segoe UI', 15, 'bold')).pack(anchor='w', pady=(0, 14))
        self.button(frame, 'Epic Secure Chat', 'chat', primary=True)
        tk.Label(frame, text='Start / Focus', bg=BG, fg=MUTED,
                 font=('Segoe UI', 9)).pack(anchor='w', pady=(8, 2))
        apps = tk.Frame(frame, bg=BG)
        apps.pack(fill='x', pady=(0, 5))
        for label, command in [('Epic', 'open-epic'), ('PowerScribe', 'open-ps360'), ('Visage', 'open-visage')]:
            tk.Button(apps, text=label, command=lambda c=command: self.command(c),
                bg=PANEL, fg=FG, activebackground=PURPLE, activeforeground=FG,
                relief='flat', pady=7, highlightcolor=PURPLE, font=('Segoe UI', 10)
            ).pack(side='left', fill='x', expand=True, padx=2)
        self.variables = {}
        for key, label, default in [('FileSync', 'Epic ↔ Visage file sync', '1'),
                ('epic', 'Epic login watcher', '1'),
                ('ps360', 'PowerScribe login watcher', '1'),
                ('visage', 'Visage login watcher', '1')]:
            var = tk.BooleanVar(value=read('Settings', key, default) == '1')
            self.variables[key] = (var, default)
            tk.Checkbutton(frame, text=label, variable=var, bg=BG, fg=FG,
                activebackground=PANEL, activeforeground=FG, selectcolor=PANEL,
                highlightcolor=PURPLE, font=('Segoe UI', 11), anchor='w',
                command=lambda k=key, v=var: self.toggle(k, v)).pack(fill='x', pady=3)
        self.all_watchers = tk.Button(frame, command=self.toggle_all,
            bg=PANEL, fg=FG, activebackground=PURPLE, activeforeground=FG,
            relief='flat', pady=7, font=('Segoe UI', 10))
        self.all_watchers.pack(fill='x', pady=3)
        self.status = tk.Label(frame, bg=BG, fg=MUTED, justify='left', anchor='w',
                               wraplength=360, height=5, font=('Segoe UI', 9))
        self.status.pack(fill='x', pady=12)
        for label, command in [('Username and password', 'settings'), ('Retry logins', 'retry'),
                               ('Restart file sync', 'restart'), ('Exit synchronization', 'exit')]:
            self.button(frame, label, command)
        self.root.update_idletasks()
        # Ask Windows for a dark title bar; unsupported Windows builds simply ignore it.
        try:
            value = ctypes.c_int(1)
            hwnd = ctypes.windll.user32.GetParent(self.root.winfo_id())
            ctypes.windll.dwmapi.DwmSetWindowAttribute(hwnd, 20, ctypes.byref(value), 4)
        except OSError:
            pass
        # Fit next to the pointer within the Windows work area (including multi-monitor setups).
        class RECT(ctypes.Structure):
            _fields_ = [(n, ctypes.c_long) for n in ('left', 'top', 'right', 'bottom')]
        class INFO(ctypes.Structure):
            _fields_ = [('size', wintypes.DWORD), ('monitor', RECT), ('work', RECT), ('flags', wintypes.DWORD)]
        user = ctypes.WinDLL('user32')
        user.MonitorFromPoint.argtypes = [wintypes.POINT, wintypes.DWORD]
        user.MonitorFromPoint.restype = wintypes.HANDLE
        user.GetMonitorInfoW.argtypes = [wintypes.HANDLE, ctypes.POINTER(INFO)]
        x, y = self.root.winfo_pointerxy()
        info = INFO(); info.size = ctypes.sizeof(info)
        user.GetMonitorInfoW(user.MonitorFromPoint(wintypes.POINT(x, y), 2), ctypes.byref(info))
        w, h = max(390, self.root.winfo_reqwidth()), self.root.winfo_reqheight()
        x = max(info.work.left, min(x - w, info.work.right - w))
        y = max(info.work.top, min(y - h, info.work.bottom - h))
        self.root.geometry(f'{w}x{h}{x:+d}{y:+d}')
        self.root.lift()
        self.refresh()

    def button(self, parent, label, command, primary=False):
        tk.Button(parent, text=label, command=lambda: self.command(command),
            bg=PURPLE if primary else PANEL, fg=FG, activebackground='#693b96',
            activeforeground=FG, relief='flat', borderwidth=0, padx=12, pady=8,
            highlightcolor=PURPLE, font=('Segoe UI', 11), anchor='w').pack(fill='x', pady=3)

    def toggle(self, key, var):
        write('Settings', key, '1' if var.get() else '0')
        write('Menu', 'Command', 'changed')

    def toggle_all(self):
        enabled = not all(read('Settings', key, '1') == '1'
                          for key in ('epic', 'ps360', 'visage'))
        for key in ('epic', 'ps360', 'visage'):
            write('Settings', key, '1' if enabled else '0')
        write('Menu', 'Command', 'changed')

    def command(self, command):
        write('Menu', 'Command', command)
        self.root.destroy()

    def refresh(self):
        for key, (var, default) in self.variables.items():
            var.set(read('Settings', key, default) == '1')
        all_on = all(read('Settings', key, '1') == '1' for key in ('epic', 'ps360', 'visage'))
        self.all_watchers.configure(text='Turn all watchers off' if all_on else 'Turn all watchers on')
        statuses = [('Epic', 'Watcher'), ('PowerScribe', 'ps360'), ('Visage', 'visage'), ('File sync', 'Sync')]
        self.status.configure(text='\n'.join(f'{label}: {read(section, "Status", "Waiting")}' for label, section in statuses))
        self.root.after(1500, self.refresh)


if __name__ == '__main__':
    Menu().root.mainloop()
