# MJ Customs Install Guide

## Before You Start

After downloading the ZIP folder, extract it to your desktop.

## 1. Create Your Server Key

1. Go to the official Cfx.re Portal: `https://portal.cfx.re/`
2. Log in with your Cfx.re account.
3. Go to **Server Keys / Keymaster**.
4. Click **Create Key**.
5. Enter your server name: **MJ Customs**.
6. Copy and save your license key inside [server-data]/server.cfg.

## 2. Open FXServer

1. Open your downloaded **artifacts/server** folder.
2. Double-click **FXServer.exe**.
3. txAdmin will open in your browser.
4. Link your Cfx.re account when prompted.
5. Create your txAdmin password.

## 3. txAdmin Setup

1. Follow the txAdmin setup prompts.
2. Name the server **MJ Customs**.
3. When you reach **Deployment Type**, choose **Existing Server Data**.
4. Select your existing server folder.
5. Paste your Cfx.re license key when txAdmin asks for it.
6. Click **Save & Run Server**.

## 4. Allow FXServer Through Firewall

1. When Windows asks for firewall access, click **Allow Access**.
2. Make sure **Private Networks** is checked.
3. If Windows does not ask, open **Windows Defender Firewall**.
4. Click **Allow an app through firewall**.
5. Click **Change Settings**.
6. Click **Allow another app**.
7. Select **FXServer.exe** from your artifacts/server folder.
8. Allow it on **Private Networks**.

## 5. Connect Locally

To join from the same PC, open FiveM and connect using:

```text
localhost:30120
```

or

```text
127.0.0.1:30120
```

## Done

Your **MJ Customs** server should now start through txAdmin.

Add Clothing Packs inside [clothing] restart server after each pack install 

> **Important:** Do not share your server key with anyone. 
