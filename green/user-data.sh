yum update -y
yum install -y nginx
systemctl start nginx
systemctl enable nginx

cat > /usr/share/nginx/html/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Green Server</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      min-height: 100vh;
      display: flex;
      align-items: center;
      justify-content: center;
      font-family: Arial, Helvetica, sans-serif;
      background: linear-gradient(135deg, #1b5e20, #388e3c, #66bb6a);
      color: #fff;
      text-align: center;
    }
    .card {
      background: rgba(255, 255, 255, 0.12);
      border: 2px solid rgba(255, 255, 255, 0.4);
      border-radius: 16px;
      padding: 50px 70px;
      box-shadow: 0 10px 30px rgba(0, 0, 0, 0.3);
    }
    h1 { font-size: 3rem; margin-bottom: 10px; }
    h2 { font-weight: normal; margin-bottom: 20px; }
    .badge {
      display: inline-block;
      background: #fff;
      color: #1b5e20;
      font-weight: bold;
      padding: 8px 20px;
      border-radius: 20px;
    }
    p { margin-top: 20px; font-size: 0.95rem; opacity: 0.9; }
  </style>
</head>
<body>
  <div class="card">
    <h1>🟢 GREEN SERVER</h1>
    <h2>Blue-Green Deployment</h2>
    <span class="badge">Version 2.0 - New Release</span>
    <p>This page is served from the <b>Green</b> environment.</p>
  </div>
</body>
</html>
EOF

systemctl restart nginx