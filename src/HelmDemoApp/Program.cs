using System.Text.Encodings.Web;

var builder = WebApplication.CreateBuilder(args);
var app = builder.Build();

app.MapGet("/", () =>
{
    var appName = HtmlEncoder.Default.Encode(Environment.GetEnvironmentVariable("APP_NAME") ?? "helm-demo");
    var message = HtmlEncoder.Default.Encode(Environment.GetEnvironmentVariable("APP_MESSAGE") ?? "Aplicación desplegada correctamente con Helm");
    var version = HtmlEncoder.Default.Encode(Environment.GetEnvironmentVariable("APP_VERSION") ?? "1.0.0");
    var environment = HtmlEncoder.Default.Encode(Environment.GetEnvironmentVariable("APP_ENVIRONMENT") ?? "Local");
    var podName = HtmlEncoder.Default.Encode(Environment.GetEnvironmentVariable("POD_NAME") ?? "ejecución-local");

    var html = $$"""
        <!doctype html>
        <html lang="es">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <title>{{appName}}</title>
          <style>
            body { font-family: system-ui, sans-serif; max-width: 42rem; margin: 4rem auto; padding: 0 1rem; color: #172554; }
            main { border: 1px solid #bfdbfe; border-radius: 1rem; padding: 2rem; background: #eff6ff; }
            dt { font-weight: 700; margin-top: 1rem; } dd { margin: .25rem 0 0; overflow-wrap: anywhere; }
          </style>
        </head>
        <body>
          <main>
            <h1>{{appName}}</h1>
            <p>{{message}}</p>
            <dl>
              <dt>Versión</dt><dd>{{version}}</dd>
              <dt>Entorno</dt><dd>{{environment}}</dd>
              <dt>Pod</dt><dd>{{podName}}</dd>
            </dl>
          </main>
        </body>
        </html>
        """;

    return Results.Content(html, "text/html; charset=utf-8");
});

app.MapGet("/health", () => Results.Text("Healthy"));

app.Run();
