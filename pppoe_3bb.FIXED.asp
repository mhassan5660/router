<html>
<head>
<meta http-equiv="Pragma" content="no-cache">
<meta http-equiv="Expires" content="-1">
<meta http-equiv="content-type" content="text/html; charset=gbk">
<meta http-equiv="Cache-Control" content="no-store, no-cache, must-revalidate, max-age=0">
<link rel="stylesheet" href="../style/style.css" type="text/css"/>
<script type="text/javascript" src="/lang/b28n.js"></script>
<script type="text/javascript" src="/js/utils.js"></script>
<script type="text/javascript" src="/js/checkValue.js"></script>
<title>WAN PPPoE Configuration</title>
<script language="JavaScript" type="text/javascript">

/* Security: Check user login status */
var checkResult = '<% cu_web_access_control(); %>';
web_access_check(checkResult);

var lang = '<% getCfgGeneral(1, "language"); %>';
Butterlate.setTextDomain("internet", lang);

var GetWANsizeSync = '<% wanNameSync(); %>';

function initValue() {
    var wan_p_n = '<% getCfgGeneral(1, "wan_pppoe_username"); %>';

    /* SECURITY FIX: Only show username, never show password in the form
     * Clear password field to require re-entry for security
     * This prevents password exposure in page source, cache, and history
     */
    document.getElementById("pppoeUser").value = wan_p_n;

    /* Don't populate password field - require user to re-enter */
    document.getElementById("pppoePass").value = "";

    /* Show indicator that password is already set */
    if (wan_p_n && wan_p_n.length > 0) {
        document.getElementById("pppoePass").placeholder = "••••••• (existing password - re-enter to change)";
        document.getElementById("pppoePassNote").innerHTML = "Password is currently set. Leave blank to keep existing password, or enter new password to change.";
    }
}

function CheckValue() {
    var pppoeUserNode = document.getElementById("pppoeUser");
    var pppoePassNode = document.getElementById("pppoePass");

    /* Validate username */
    if (!CheckNotNull(pppoeUserNode.value)) {
        alert(_("wPppoeCon_userNullAlert"));
        pppoeUserNode.focus();
        return false;
    }

    /* Validate username format - alphanumeric, dots, hyphens, underscores, @
     * Length: 1-128 characters
     */
    var usernamePattern = /^[a-zA-Z0-9._@\-]{1,128}$/;
    if (!usernamePattern.test(pppoeUserNode.value)) {
        alert("Invalid username format. Only letters, numbers, dots, hyphens, underscores, and @ are allowed.");
        pppoeUserNode.focus();
        return false;
    }

    /* Validate password - if provided
     * PPPoE password can contain most printable characters
     * But we restrict for safety: alphanumeric and safe special chars
     */
    if (pppoePassNode.value.length > 0) {
        var passwordPattern = /^[a-zA-Z0-9!@#$%^&*\-_=+]{1,128}$/;
        if (!passwordPattern.test(pppoePassNode.value)) {
            alert("Invalid password format. Only alphanumeric and these special characters are allowed: !@#$%^&*-_=+");
            pppoePassNode.focus();
            return false;
        }

        if (!CheckNotNull(pppoePassNode.value)) {
            alert(_("wPppoeCon_pwdNullAlert"));
            pppoePassNode.focus();
            return false;
        }
    }

    return true;
}

/* CSRF Protection - add token to form submission */
function addCsrfToken() {
    var token = '<% getCsrfToken(); %>';
    var csrfInput = document.createElement("input");
    csrfInput.type = "hidden";
    csrfInput.name = "csrf_token";
    csrfInput.value = token;
    document.getElementById("pppoecfg").appendChild(csrfInput);
}

window.onload = function() {
    initValue();
    addCsrfToken();
};

</script>
</head>
<body class="mainbody">
<form method="post" name="pppoecfg" id="pppoecfg" action="/goform/WanConnection" onSubmit="return CheckValue()">
  <table border="0" cellpadding="0" cellspacing="0" width="100%">
    <tbody>
      <tr>
        <td class="prompt"><table border="0" cellpadding="0" cellspacing="0" width="100%">
            <tbody>
              <tr>
                <td id="lan_prompt" class="title_01" style="padding-left: 10px;" width="100%">
                  Configure PPPoE connection parameters. Enter your ISP-provided username and password.
                </td>
              </tr>
            </tbody>
          </table></td>
      </tr>
    </tbody>
  </table>
  <table border="0" cellpadding="0" cellspacing="0" width="100%">
    <tbody>
      <tr>
        <td height="5px"></td>
      </tr>
    </tbody>
  </table>
  <table class="tabal_bg" border="0" cellpadding="0" cellspacing="1" width="100%">
    <tbody>
      <tr class="tabal_head">
        <td colspan="2" id="lSetup">PPPoE Setup</td>
      </tr>

      <tr>
        <td class="tabal_left" width="25%" id="wPppoeUser">User Name</td>
        <td class="tabal_right">
          <input name="pppoeUser" id="pppoeUser" maxlength="128" style="width:320px;"
                 pattern="[a-zA-Z0-9._@\-]{1,128}" required>
          <strong style="color:#FF0033">*</strong>
          <span class="gray" id="wPppoeCon_userTips">Enter your PPPoE username provided by your ISP</span>
        </td>
      </tr>

      <tr>
        <td class="tabal_left" width="25%" id="wPppoePassword">Password</td>
        <td class="tabal_right">
          <input type="password" name="pppoePass" id="pppoePass" maxlength="128" style="width:320px;"
                 pattern="[a-zA-Z0-9!@#$%^&*\-_=+]{1,128}" required>
          <strong style="color:#FF0033">*</strong>
          <span class="gray" id="wPppoeCon_pwdTips">Enter your PPPoE password provided by your ISP</span>
          <div id="pppoePassNote" style="color: #666; font-size: 12px; margin-top: 5px;"></div>
        </td>
      </tr>

      <!-- Security notice -->
      <tr>
        <td colspan="2" style="padding: 10px; background-color: #f9f9f9;">
          <div style="color: #333; font-size: 12px;">
            <strong>Security Note:</strong> Your PPPoE password is never displayed in the page for your protection.
            If you don't see a password value, it means the field is empty and you must enter your password to proceed.
          </div>
        </td>
      </tr>

    </tbody>
  </table>

  <table id="tb_submit" class="tabal_button" border="0" cellpadding="0" cellspacing="0" width="100%">
    <tbody>
      <tr>
        <td class="tabal_submit" width="25%"></td>
        <td class="tabal_submit">
          <input type="submit" value="Apply" id="lApply" class="submit" onClick="TimeoutReload(20)">
          <input type="reset" name="Cancel" value="Cancel" id="lCancel" class="submit" onClick="window.location.reload()">
        </td>
      </tr>
    </tbody>
  </table>
</form>
</body>
</html>
