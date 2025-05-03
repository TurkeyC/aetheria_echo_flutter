import requests

def check():
    try:
        r = requests.get("http://localhost:80/api/health", timeout=3)
        if r.status_code == 200 and r.json().get("status") == "ok":
            print("后端健康检查通过")
        else:
            print("后端健康检查失败", r.text)
    except Exception as e:
        print("后端健康检查异常", e)

if __name__ == "__main__":
    check()
