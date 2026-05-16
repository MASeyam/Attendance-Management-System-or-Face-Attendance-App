import io
import base64
import smtplib
from email.mime.image import MIMEImage
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText

try:
    import qrcode
    _QR_AVAILABLE = True
except ImportError:
    _QR_AVAILABLE = False

from config import EMAIL_USER, EMAIL_PASS

APP_DOWNLOAD_URL = 'https://classeye.fue.edu.eg/download'


def _generate_qr_bytes() -> bytes | None:
    if not _QR_AVAILABLE:
        return None
    try:
        qr = qrcode.QRCode(version=1, box_size=8, border=2,
                           error_correction=qrcode.constants.ERROR_CORRECT_M)
        qr.add_data(APP_DOWNLOAD_URL)
        qr.make(fit=True)
        img = qr.make_image(fill_color='#1E3A5F', back_color='white')
        buf = io.BytesIO()
        img.save(buf, format='PNG')
        return buf.getvalue()
    except Exception as e:
        print(f'QR generation error: {e}')
        return None


def send_login_credentials(
    personal_email: str,
    full_name: str,
    login_email: str,
    password: str,
    role: str,
) -> None:
    if not EMAIL_USER:
        print('Email skipped — EMAIL_USER not set in .env')
        return

    try:
        qr_bytes   = _generate_qr_bytes()
        has_qr     = qr_bytes is not None
        qr_section = (
            '<p style="margin:0 0 12px">Scan the QR code below to download the ClassEye app:</p>'
            '<img src="cid:qr_code" alt="Download QR" width="180" height="180" style="border-radius:12px"/>'
        ) if has_qr else (
            f'<p style="margin:0 0 12px">Download the app at: '
            f'<a href="{APP_DOWNLOAD_URL}" style="color:#4C9BE8">{APP_DOWNLOAD_URL}</a></p>'
        )

        html = f"""<!DOCTYPE html>
<html>
<head><meta charset="utf-8"></head>
<body style="margin:0;padding:0;background:#F5F7FA;font-family:'Helvetica Neue',Arial,sans-serif">
  <table width="100%" cellpadding="0" cellspacing="0" style="background:#F5F7FA;padding:32px 0">
    <tr><td align="center">
      <table width="560" cellpadding="0" cellspacing="0"
             style="background:#FFFFFF;border-radius:16px;overflow:hidden;
                    box-shadow:0 4px 24px rgba(0,0,0,0.08)">

        <!-- Header -->
        <tr>
          <td style="background:linear-gradient(135deg,#1E3A5F,#4C9BE8);
                     padding:32px 40px;text-align:center">
            <p style="margin:0;font-size:28px;font-weight:700;color:#FFFFFF;
                       letter-spacing:2px">ClassEye</p>
            <p style="margin:6px 0 0;font-size:13px;color:rgba(255,255,255,0.75)">
              Attendance Management System</p>
          </td>
        </tr>

        <!-- Body -->
        <tr>
          <td style="padding:36px 40px">
            <p style="margin:0 0 18px;font-size:16px;color:#1A1A2E">
              Dear <strong>{full_name}</strong>,</p>
            <p style="margin:0 0 24px;font-size:14px;color:#6B7280;line-height:1.7">
              Welcome to ClassEye at FUE! Your <strong>{role}</strong> account has
              been created successfully.</p>

            <!-- Credentials box -->
            <table width="100%" cellpadding="0" cellspacing="0"
                   style="background:#F5F7FA;border-radius:12px;
                          border:1px solid #E5E7EB;margin-bottom:28px">
              <tr>
                <td style="padding:20px 24px">
                  <p style="margin:0 0 6px;font-size:11px;font-weight:600;
                             letter-spacing:1px;color:#6B7280">LOGIN CREDENTIALS</p>
                  <table width="100%" cellpadding="0" cellspacing="0">
                    <tr>
                      <td style="padding:8px 0;font-size:13px;color:#6B7280;width:90px">Email</td>
                      <td style="padding:8px 0;font-size:13px;font-weight:600;
                                 color:#1E3A5F">{login_email}</td>
                    </tr>
                    <tr>
                      <td style="padding:8px 0;font-size:13px;color:#6B7280">Password</td>
                      <td style="padding:8px 0;font-size:14px;font-weight:700;
                                 color:#1E3A5F;letter-spacing:1px">{password}</td>
                    </tr>
                  </table>
                </td>
              </tr>
            </table>

            <!-- QR / Download -->
            <table width="100%" cellpadding="0" cellspacing="0"
                   style="background:#EBF4FF;border-radius:12px;
                          border:1px solid #BFDBFE;margin-bottom:24px">
              <tr>
                <td style="padding:24px;text-align:center">
                  <p style="margin:0 0 4px;font-size:13px;font-weight:600;
                             color:#1E3A5F">Download ClassEye App</p>
                  {qr_section}
                </td>
              </tr>
            </table>

            <p style="margin:0 0 4px;font-size:13px;color:#6B7280">
              ⚠️ Please change your password after your first login.</p>
          </td>
        </tr>

        <!-- Footer -->
        <tr>
          <td style="background:#F5F7FA;padding:20px 40px;text-align:center;
                     border-top:1px solid #E5E7EB">
            <p style="margin:0;font-size:12px;color:#9CA3AF">
              FUE — Faculty of Computers &amp; Information Technology</p>
            <p style="margin:4px 0 0;font-size:11px;color:#9CA3AF">
              This is an automated message. Do not reply to this email.</p>
          </td>
        </tr>

      </table>
    </td></tr>
  </table>
</body>
</html>"""

        # Build MIME message
        msg = MIMEMultipart('related')
        msg['From']    = EMAIL_USER
        msg['To']      = personal_email
        msg['Subject'] = 'Welcome to ClassEye — Your Login Credentials'

        alt = MIMEMultipart('alternative')
        msg.attach(alt)
        alt.attach(MIMEText(html, 'html'))

        if has_qr:
            qr_img = MIMEImage(qr_bytes, _subtype='png')
            qr_img.add_header('Content-ID', '<qr_code>')
            qr_img.add_header('Content-Disposition', 'inline', filename='qr_code.png')
            msg.attach(qr_img)

        server = smtplib.SMTP('smtp.gmail.com', 587)
        server.starttls()
        server.login(EMAIL_USER, EMAIL_PASS)
        server.send_message(msg)
        server.quit()
        print(f'Credentials email sent to {personal_email}')

    except Exception as e:
        print(f'Email Error: {e}')
