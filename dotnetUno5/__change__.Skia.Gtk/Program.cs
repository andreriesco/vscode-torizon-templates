using System;
using GLib;
using Uno.UI.Runtime.Skia.Gtk;

namespace __change__.Skia.Gtk;

public class Program
{
    public static void Main(string[] args)
    {
        // FIXME: this is needed to be able to have the GTK IME for onboard keyboard
        Uno.UI.FeatureConfiguration.TextBox.UseOverlayOnSkia = true;

        ExceptionManager.UnhandledException += delegate (UnhandledExceptionArgs expArgs)
        {
            Console.WriteLine("GLIB UNHANDLED EXCEPTION" + expArgs.ExceptionObject.ToString());
            expArgs.ExitApplication = true;
        };

        var host = new GtkHost(() => new AppHead());
        // FIXME: if your machine supports openGL remove this
        host.RenderSurfaceType = RenderSurfaceType.Software;

        host.Run();
    }
}
