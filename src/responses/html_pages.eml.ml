let login_successful_tmpl ?(app_name="FPauth") auth =
  <!DOCTYPE html>
  <html>
    <head>
      <meta charset="utf-8">
      <title><%s app_name^" login successful"%></title>
    </head>
    <body>
      <div id="auth">Authentication status: <%s Bool.to_string auth%></div>
    </body>
  </html>

let login_error_tmpl ?(app_name="FPauth") err =
  <!DOCTYPE html>
  <html>
    <head>
      <meta charset="utf-8">
      <title><%s app_name^" login error"%></title>
    </head>
    <body>
      <div id="error">Authentication error: <%s err%></div>
    </body>
  </html>

let logout_tmpl ?(app_name="FPauth") auth =
  <!DOCTYPE html>
  <html>
    <head>
      <meta charset="utf-8">
      <title><%s app_name^" logout"%></title>
    </head>
    <body>
      <div id="auth">Authentication status: <%s Bool.to_string auth%></div>
    </body>
  </html>