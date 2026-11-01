import http.server
import socketserver
import socket
import os
import sys

PORT = 8080
DIRECTORY = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'web_mobile')

class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=DIRECTORY, **kwargs)

def get_lan_ips():
    ips = []
    try:
        hostname = socket.gethostname()
        for ip in socket.gethostbyname_ex(hostname)[2]:
            if not ip.startswith('127.') and not ip.startswith('169.254.'):
                ips.append(ip)
    except Exception:
        pass
    return ips or ['127.0.0.1']

def main():
    ips = get_lan_ips()
    print("=" * 60)
    print(" 🚀 手机端通讯录导入助手 - 局域网服务已启动！")
    print("=" * 60)
    print("\n请确保手机与当前电脑连接【同一个 WiFi 或热点】")
    print("在手机浏览器（微信、Chrome、自带浏览器均可）中直接打开以下任一网址：\n")
    for ip in ips:
        print(f"   👉 http://{ip}:{PORT}")
    print("\n手机打开后：")
    print(" 1. 直接选择 Excel/CSV 或粘贴人名手机号文本；")
    print(" 2. 勾选“来电显示优化”（将自动生成 张三-研发部-架构师）；")
    print(" 3. 点击【一键导入到手机系统通讯录】；")
    print(" 4. 安卓手机自带通讯录将自动弹出，点击确认即可瞬间全部录入！")
    print("=" * 60)
    print("（按 Ctrl+C 可停止服务）\n")

    with socketserver.TCPServer(("", PORT), Handler) as httpd:
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\n服务已平稳停止。")

if __name__ == '__main__':
    main()
