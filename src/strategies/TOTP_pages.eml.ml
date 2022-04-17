let error_tmpl ~app_name err =
  <!DOCTYPE html>
  <html>
    <head>
      <meta charset="utf-8">
      <title><%s app_name^" TOTP error"%></title>
    </head>
    <body>
      <div id="error">TOTP setup error: <%s err%></div>
    </body>
  </html>

let secret_tmpl ~app_name request form_url secret =
  <!DOCTYPE html>
  <html>
    <head>
      <meta charset="utf-8">
      <title><%s app_name^" TOTP secret"%></title>
    </head>
    <body>
      <div id="secret">
        <p id="secret line">TOTP secret: <%s secret%></p>
        <p id="secret comment">Add this secret in your code-generating app (like Google Authenticator).</p>
      </div>
      <form method="POST" action=<%s form_url%> >
        <%s! Dream.csrf_tag request %>
        <input id="totp_code" name="totp_code">
        <button id="submit_code" type="submit">Submit</button>
      </form>
    </body>
  </html>

let finish_tmpl ~app_name () =
  <!DOCTYPE html>
  <html>
    <head>
      <meta charset="utf-8">
      <title><%s app_name^" TOTP finished"%></title>
    </head>
    <body>
      <div id="message">TOTP setup finished. You can now send Time-based One-time passwords for authentication.</div>
    </body>
  </html>