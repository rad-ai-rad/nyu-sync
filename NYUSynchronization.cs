// Build with Build-NYUSynchronization.ps1. No credentials in arguments, logs, or shared files.
using System;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Text;
using System.Threading;
using System.Windows.Automation;
using System.Windows.Forms;
using System.Drawing;

static class NYUSynchronization {
    static readonly string Home = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "State");
    static readonly string State = Path.Combine(Home, "watcher.ini");
    static readonly string Vault = Path.Combine(Home, "credentials.dpapi");
    [DllImport("kernel32", CharSet=CharSet.Unicode)] static extern uint GetPrivateProfileString(string section,string key,string def,StringBuilder value,uint size,string path);
    [DllImport("kernel32", CharSet=CharSet.Unicode)] static extern bool WritePrivateProfileString(string section,string key,string value,string path);
    [DllImport("user32")] static extern IntPtr OpenInputDesktop(uint flags,bool inherit,uint access);
    [DllImport("user32")] static extern bool SwitchDesktop(IntPtr desktop);
    [DllImport("user32")] static extern bool CloseDesktop(IntPtr desktop);
    [DllImport("user32")] static extern bool GetLastInputInfo(ref LASTINPUTINFO input);
    [StructLayout(LayoutKind.Sequential)] struct LASTINPUTINFO { public uint cbSize,dwTime; }
    [DllImport("user32")] static extern bool EnumWindows(EnumWindow callback,IntPtr data);
    delegate bool EnumWindow(IntPtr window,IntPtr data);
    [DllImport("user32")] static extern uint GetWindowThreadProcessId(IntPtr window,out uint process);
    [DllImport("user32")] static extern bool IsWindowVisible(IntPtr window);

    static string Get(string section,string key,string fallback) {
        var b=new StringBuilder(2048); GetPrivateProfileString(section,key,fallback,b,2048,State); return b.ToString();
    }
    static void Put(string section,string key,string value) { if(!WritePrivateProfileString(section,key,value,State)) throw new IOException(); }
    static bool Enabled(string app) { return Get("Settings",app,"1")=="1"; }
    static string[] ReadCredentials(string path) {
        byte[] encrypted=File.ReadAllBytes(path), plain=null;
        try {
            if(encrypted.Length<32 || encrypted.Length>65536) throw new InvalidDataException();
            plain=ProtectedData.Unprotect(encrypted,null,DataProtectionScope.CurrentUser);
            var fields=Encoding.UTF8.GetString(plain).TrimEnd('\0').Split(new[]{'\n'},3);
            if(fields.Length!=3 || fields[0]!="NYUSynchronization/1" || fields[1].Length==0 || fields[2].Length==0) throw new InvalidDataException();
            return new[]{fields[1],fields[2]};
        } finally { if(plain!=null) Array.Clear(plain,0,plain.Length); }
    }
    static void SaveCredentials(string path,string user,string password) {
        if(String.IsNullOrWhiteSpace(user) || String.IsNullOrEmpty(password) || user.IndexOfAny(new[]{'\r','\n','\0'})>=0 || password.IndexOfAny(new[]{'\r','\n','\0'})>=0) throw new InvalidDataException();
        byte[] plain=Encoding.UTF8.GetBytes("NYUSynchronization/1\n"+user+"\n"+password+"\0");
        string temp=path+"."+Guid.NewGuid().ToString("N")+".tmp";
        try {
            byte[] encrypted=ProtectedData.Protect(plain,null,DataProtectionScope.CurrentUser);
            File.WriteAllBytes(temp,encrypted);
            // Validate the new encrypted file before replacing the working credential file.
            var check=ReadCredentials(temp);
            if(check[0]!=user || check[1]!=password) throw new InvalidDataException();
            check[1]="";
            if(File.Exists(path)) File.Replace(temp,path,null); else File.Move(temp,path);
        } finally { Array.Clear(plain,0,plain.Length); if(File.Exists(temp)) File.Delete(temp); }
    }
    static void ResetAttempts() {
        Put("Login","Attempted","0");
        foreach(string app in new[]{"ps360","visage"}) Put(app,"Attempted","0");
        Put("Settings","Attention","0"); Put("Settings","RetryGeneration",Guid.NewGuid().ToString("N"));
    }
    static bool DesktopReady() {
        var d=OpenInputDesktop(0,false,0x100); if(d==IntPtr.Zero)return false;
        try { if(!SwitchDesktop(d))return false; } finally { CloseDesktop(d); }
        var input=new LASTINPUTINFO{cbSize=(uint)Marshal.SizeOf(typeof(LASTINPUTINFO))};
        return GetLastInputInfo(ref input) && unchecked((uint)Environment.TickCount-input.dwTime)>=60000;
    }
    static AutomationElement ById(AutomationElement root,string id) {
        return root.FindFirst(TreeScope.Descendants,new PropertyCondition(AutomationElement.AutomationIdProperty,id));
    }
    static AutomationElement Button(AutomationElement root,string name) {
        return root.FindFirst(TreeScope.Descendants,new AndCondition(new PropertyCondition(AutomationElement.ControlTypeProperty,ControlType.Button),new PropertyCondition(AutomationElement.NameProperty,name)));
    }
    static string Value(AutomationElement e) { return ((ValuePattern)e.GetCurrentPattern(ValuePattern.Pattern)).Current.Value; }
    static void Set(AutomationElement e,string value) {
        if(e==null || !e.Current.IsEnabled || e.Current.IsOffscreen) throw new InvalidOperationException();
        ((ValuePattern)e.GetCurrentPattern(ValuePattern.Pattern)).SetValue(value);
    }
    static void Status(string app,string value) { Put(app,"Status",value); Put(app,"Checked",DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss")); }
    static string VisageId(string suffix) { return "VisageLayoutBase.mContent.stackedWidget.page."+suffix; }
    static void Scan(string app) {
        if(!DesktopReady() || Get("Settings","Paused","0")=="1")return;
        if(!Enabled(app)) {Status(app,"Disabled"); return;}
        string processName=app=="ps360"?"Nuance.PowerScribe360":"vsclient";
        string expected=Get("Paths",app,"");
        if(expected=="" || !File.Exists(expected)) {Status(app,"Application path needs configuration");return;}
        var processes=Process.GetProcessesByName(processName);
        if(processes.Length==0) {
            Status(app,"Not running");
            return;
        }
        var matches=processes.Where(p=> {try{return String.Equals(p.MainModule.FileName,expected,StringComparison.OrdinalIgnoreCase);}catch{return false;}}).ToArray();
        if(matches.Length!=1) {Status(app,"Multiple or unrecognized processes; waiting");return;}
        int pid=matches[0].Id;
        var roots=new System.Collections.Generic.List<AutomationElement>();
        EnumWindows((h,p)=> {uint owner;GetWindowThreadProcessId(h,out owner);if(owner==pid && IsWindowVisible(h)) {try{roots.Add(AutomationElement.FromHandle(h));}catch{}}return true;},IntPtr.Zero);
        AutomationElement loginRoot=null,user=null,password=null,submit=null;
        foreach(var root in roots) {
            AutomationElement u=ById(root,app=="ps360"?"textBoxUsername":VisageId("userName_lineEdit"));
            AutomationElement p=ById(root,app=="ps360"?"textBoxPassword":VisageId("password_lineEdit"));
            AutomationElement b=app=="ps360"?ById(root,"buttonLogin"):Button(root,"Login");
            if(u!=null && p!=null && b!=null && !u.Current.IsOffscreen && !p.Current.IsOffscreen) {
                if(loginRoot!=null){Status(app,"Multiple login forms; waiting");return;}
                loginRoot=root;user=u;password=p;submit=b;
            }
        }
        if(loginRoot==null) {
            // No form is not proof of authentication. Keep the attempt latch until a positive signal.
            bool authenticated=app=="visage" && roots.Any(root=>root.Current.Name.StartsWith("Visage Client - ",StringComparison.Ordinal)
                && root.Current.Name.Contains("@visage cdc") && ById(root,"ExWorklistContentBase")!=null);
            authenticated=authenticated || (app=="ps360" && roots.Any(root=> {
                var explorer=ById(root,"explorerControl");
                return explorer!=null && !explorer.Current.IsOffscreen && ById(root,"toolBarExplorer")!=null;
            }));
            authenticated=authenticated || roots.Any(root=>root.FindFirst(TreeScope.Descendants,new OrCondition(
                new PropertyCondition(AutomationElement.NameProperty,"Log Out"),
                new PropertyCondition(AutomationElement.NameProperty,"Log Off"),
                new PropertyCondition(AutomationElement.NameProperty,"Logout")))!=null);
            if(authenticated) {Put(app,"Attempted","0");Status(app,"Authenticated");}
            else Status(app,"Running; authentication unverified");
            return;
        }
        if(app=="visage") {
            var server=ById(loginRoot,VisageId("serverName_comboBox"));
            string host=server==null?"":Value(server).Trim();
            if(!String.Equals(host,"visage.nyumc.org",StringComparison.OrdinalIgnoreCase)) {Status(app,"Different Visage server; manual login required");return;}
            var iwa=ById(loginRoot,VisageId("iwa_checkbox"));
            if(iwa!=null && ((TogglePattern)iwa.GetCurrentPattern(TogglePattern.Pattern)).Current.ToggleState!=ToggleState.Off) {Status(app,"Windows authentication selected; manual login required");return;}
        }
        if(app=="ps360" && !submit.Current.IsEnabled) {
            var wait=ById(loginRoot,"labelWait");
            Status(app,wait!=null && wait.Current.Name=="Loading local speaker profile..."?"Signed in; loading speaker profile":"Login in progress");return;
        }
        if(Get(app,"Attempted","0")=="1") {Status(app,"Login already attempted; check app or Retry logins");return;}
        if(!DesktopReady()) {Status(app,"Login ready; waiting for idle desktop");return;}
        if(!File.Exists(Vault)) {Status(app,"Set NYU credentials");return;}
        var credentials=ReadCredentials(Vault);
        try {
            // Target UIA element handles, never global keyboard input. Recheck ownership and exact fields.
            if(user.Current.ProcessId!=pid || password.Current.ProcessId!=pid || submit.Current.ProcessId!=pid || !submit.Current.IsEnabled || !password.Current.IsPassword) {
                Status(app,"Login form verification failed");return;
            }
            if(!DesktopReady() || Get("Settings","Paused","0")=="1")return;
            Put(app,"Attempted","1");
            Set(user,credentials[0]);
            if(!DesktopReady()) {Status(app,"Login interrupted; use Retry logins");return;}
            Set(password,credentials[1]);
            if(Value(user)!=credentials[0] || !DesktopReady()) {Status(app,"Login interrupted; use Retry logins");return;}
            ((InvokePattern)submit.GetCurrentPattern(InvokePattern.Pattern)).Invoke();
            Status(app,"Login submitted; awaiting confirmation");
        } finally {credentials[1]="";}
    }
    static void Settings() {
        Application.EnableVisualStyles();
        var form=new Form{Text="NYU Sync",ClientSize=new Size(510,500),StartPosition=FormStartPosition.CenterScreen,FormBorderStyle=FormBorderStyle.FixedDialog,MaximizeBox=false,Font=new Font("Segoe UI",10),AutoScaleMode=AutoScaleMode.Dpi};
        form.Icon = Icon.ExtractAssociatedIcon(Application.ExecutablePath);
        var owner=new Label{Left=22,Top=18,Width=468,Text="Windows account: "+Environment.UserDomainName+"\\"+Environment.UserName};
        var userLabel=new Label{Left=22,Top=55,Width=120,Text="NYU username"};
        var user=new TextBox{Left=150,Top=52,Width=330};
        var passLabel=new Label{Left=22,Top=93,Width=120,Text="New password"};
        var pass=new TextBox{Left=150,Top=90,Width=330,UseSystemPasswordChar=true};
        var hint=new Label{Left=150,Top=120,Width=335,Height=34,Text="Leave blank to keep the saved password."};
        try{var c=ReadCredentials(Vault);user.Text=c[0];c[1]="";}catch{hint.Text="Enter your NYU username and password.";}
        var epic=new CheckBox{Left=22,Top=165,Width=140,Text="Citrix / Epic",Checked=Enabled("epic")};
        var ps=new CheckBox{Left=185,Top=165,Width=155,Text="PowerScribe 360",Checked=Enabled("ps360")};
        var visage=new CheckBox{Left=365,Top=165,Width=120,Text="Visage",Checked=Enabled("visage")};
        var status=new Label{Left=22,Top=243,Width=463,Height=135};
        var note=new Label{Left=22,Top=388,Width=465,Height=42,Text="Login watchers pause while this window is open."};
        var retry=new Button{Left=22,Top=448,Width=125,Height=32,Text="Retry logins"};
        var save=new Button{Left=267,Top=448,Width=105,Height=32,Text="Save"};
        var close=new Button{Left=382,Top=448,Width=98,Height=32,Text="Close"};
        var timer=new System.Windows.Forms.Timer{Interval=2000};
        Action refresh=()=>status.Text="Epic: "+Get("Watcher","Status","Waiting")+"\nPowerScribe: "+Get("ps360","Status","Waiting")+"\nVisage: "+Get("visage","Status","Waiting")+"\nFile sync: "+Get("Sync","Status","Waiting");
        timer.Tick+=(s,e)=>refresh();timer.Start();refresh();
        retry.Click+=(s,e)=>{ResetAttempts();note.Text="One new login attempt enabled for each app.";};
        save.Click+=(s,e)=>{
            try {
                string username=user.Text.Trim(), secret=pass.Text;
                if(secret.Length==0) {
                    var old=ReadCredentials(Vault);
                    if(username!=old[0]) {old[1]="";note.Text="Enter a password when changing the username.";return;}
                    secret=old[1];old[1]="";
                }
                SaveCredentials(Vault,username,secret);secret="";pass.Clear();
                Put("Settings","epic",epic.Checked?"1":"0");Put("Settings","ps360",ps.Checked?"1":"0");Put("Settings","visage",visage.Checked?"1":"0");
                ResetAttempts();note.Text="Saved with Windows encryption for this account.";
            }catch{note.Text="Could not save. Check the username and password.";}
        };
        close.Click+=(s,e)=>form.Close();
        form.Controls.AddRange(new Control[]{owner,userLabel,user,passLabel,pass,hint,epic,ps,visage,status,note,retry,save,close});
        form.FormClosed+=(s,e)=>{timer.Stop();timer.Dispose();pass.Clear();};
        Application.Run(form);
    }
    static int SelfTest() {
        string path=Path.Combine(Home,"test-"+Guid.NewGuid().ToString("N")+".dpapi");
        try {
            SaveCredentials(path,"test-user","test-!+^# unicode \u03b1");
            var c=ReadCredentials(path);if(c[0]!="test-user" || c[1]!="test-!+^# unicode \u03b1")return 2;
            SaveCredentials(path,"second-user","replacement");c=ReadCredentials(path);if(c[0]!="second-user" || c[1]!="replacement")return 3;
            byte[] bytes=File.ReadAllBytes(path);bytes[bytes.Length-1]^=1;File.WriteAllBytes(path,bytes);
            try{ReadCredentials(path);return 4;}catch(CryptographicException){}
            if(File.Exists(Vault)){c=ReadCredentials(Vault);c[1]="";}
            return 0;
        }finally{if(File.Exists(path))File.Delete(path);}
    }
    [STAThread] static int Main(string[] args) {
        Directory.CreateDirectory(Home);
        try {
            if(args.Length>0 && args[0]=="--self-test")return SelfTest();
            using(var gate=new Mutex(false,"Local\\NYUSynchronization.Settings")) {
            if(!gate.WaitOne(args.Length>0 && args[0]=="--scan"?0:30000))return 0;
            try { if(args.Length>0 && args[0]=="--scan") {
                if(Get("Settings","Paused","0")=="1")return 0;
                foreach(string app in new[]{"ps360","visage"})try{Scan(app);}catch{Status(app,"Check app; automatic login unavailable");}
            }else Settings();
            }finally{gate.ReleaseMutex();}
            }
            return 0;
        }catch{return 1;}
    }
}
