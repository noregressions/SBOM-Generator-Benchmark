// Touches each shipped package so the app plausibly uses them; the benchmark never runs it.
var json = Newtonsoft.Json.JsonConvert.SerializeObject(new { ok = true });
var log = log4net.LogManager.GetLogger(typeof(object));
using var zip = new System.IO.MemoryStream();
using (var z = new ICSharpCode.SharpZipLib.Zip.ZipOutputStream(zip)) { }
System.Console.WriteLine(json + (log is null ? "" : " logged"));
