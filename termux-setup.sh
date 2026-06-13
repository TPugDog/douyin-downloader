#!/data/data/com.termux/files/usr/bin/bash
# ============================================
# 抖音视频下载器 - Termux 一键安装脚本
# 在手机上运行: 不需要编译, 不需要电脑
# ============================================

set -e

echo "=============================="
echo " 抖音视频下载器 - Termux 安装"
echo "=============================="
echo ""

# 1. 更新包管理器
echo "[1/5] 更新包管理器..."
pkg update -y && pkg upgrade -y

# 2. 安装 Python
echo "[2/5] 安装 Python..."
pkg install -y python

# 3. 安装 pip 依赖
echo "[3/5] 安装 Python 依赖 (yt-dlp, flask)..."
pip install yt-dlp flask requests

# 4. 创建项目目录
echo "[4/5] 创建项目文件..."
mkdir -p ~/douyin-downloader/public

# 下载前端页面
cat > ~/douyin-downloader/public/index.html << 'HTMLEOF'
<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <title>抖音视频下载器</title>
  <style>
    *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
    :root {
      --bg: #0f0f13;
      --card: #1a1a23;
      --border: #2a2a3a;
      --text: #e8e8f0;
      --muted: #8888a0;
      --accent: #ff2e5b;
      --accent-hover: #ff4777;
      --success: #34d399;
      --radius: 12px;
    }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
      background: var(--bg);
      color: var(--text);
      min-height: 100vh;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      padding: 16px;
    }
    .container { width: 100%; max-width: 480px; margin: 0 auto; }
    .header { text-align: center; margin-bottom: 24px; }
    .header h1 {
      font-size: 24px; font-weight: 700;
      background: linear-gradient(135deg, #ff2e5b, #ff6b3d);
      -webkit-background-clip: text;
      -webkit-text-fill-color: transparent;
      background-clip: text;
      margin-bottom: 6px;
    }
    .header p { color: var(--muted); font-size: 14px; }
    .card {
      background: var(--card);
      border: 1px solid var(--border);
      border-radius: var(--radius);
      padding: 20px;
    }
    .input-group { display: flex; gap: 8px; margin-bottom: 12px; }
    .input-group input {
      flex: 1;
      background: var(--bg);
      border: 1px solid var(--border);
      border-radius: 8px;
      padding: 12px 14px;
      color: var(--text);
      font-size: 15px;
      outline: none;
      transition: border-color 0.2s;
    }
    .input-group input:focus { border-color: var(--accent); }
    .input-group input::placeholder { color: #555; }
    .btn {
      background: var(--accent); color: white; border: none;
      border-radius: 8px; padding: 12px 20px;
      font-size: 15px; font-weight: 600; cursor: pointer;
      transition: background 0.2s, transform 0.1s;
      white-space: nowrap; display: inline-flex; align-items: center; gap: 6px;
    }
    .btn:hover { background: var(--accent-hover); }
    .btn:active { transform: scale(0.97); }
    .btn:disabled { opacity: 0.5; cursor: not-allowed; transform: none; }
    .btn-download { background: var(--success); color: #0f0f13; }
    .btn-download:hover { background: #6ee7b7; }
    .tips { color: var(--muted); font-size: 13px; line-height: 1.6; }
    .loading { display: none; text-align: center; margin: 16px 0; }
    .loading.active { display: block; }
    .spinner {
      width: 36px; height: 36px;
      border: 3px solid var(--border);
      border-top-color: var(--accent);
      border-radius: 50%;
      animation: spin 0.8s linear infinite;
      margin: 0 auto 10px;
    }
    @keyframes spin { to { transform: rotate(360deg); } }
    .loading p { color: var(--muted); font-size: 14px; }
    .result { display: none; margin-top: 16px; }
    .result.active { display: block; }
    .result-card { background: var(--bg); border: 1px solid var(--border); border-radius: 10px; overflow: hidden; }
    .result-video {
      width: 100%; aspect-ratio: 9 / 16; max-height: 360px;
      object-fit: contain; background: #000; display: block;
    }
    .result-info { padding: 14px; }
    .result-title { font-size: 14px; font-weight: 500; margin-bottom: 4px; overflow: hidden; text-overflow: ellipsis; display: -webkit-box; -webkit-line-clamp: 2; -webkit-box-orient: vertical; }
    .result-author { color: var(--muted); font-size: 13px; margin-bottom: 12px; }
    .result-actions .btn { width: 100%; justify-content: center; font-size: 14px; padding: 12px; }
    .error-msg {
      display: none;
      background: rgba(255, 46, 91, 0.1);
      border: 1px solid rgba(255, 46, 91, 0.3);
      color: #ff6b8a; padding: 10px 14px;
      border-radius: 8px; font-size: 13px;
      margin-top: 12px;
    }
    .error-msg.active { display: block; }
    .steps { margin-top: 16px; text-align: center; }
    .steps p { color: var(--muted); font-size: 12px; margin-bottom: 6px; }
    .step-tag {
      display: inline-block; padding: 3px 8px;
      background: var(--card); border: 1px solid var(--border);
      border-radius: 6px; font-size: 12px; color: #8888bb;
      margin: 2px;
    }
    .footer { text-align: center; margin-top: 20px; color: var(--muted); font-size: 12px; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>抖音视频下载器</h1>
      <p>粘贴分享链接，一键下载无水印视频</p>
    </div>
    <div class="card">
      <div class="input-group">
        <input type="text" id="shareUrl" placeholder="粘贴抖音分享链接" autocomplete="off" spellcheck="false" />
        <button class="btn" id="getBtn">解析</button>
      </div>
      <div class="tips">在抖音点分享 → 复制链接，直接粘贴即可</div>
      <div class="loading" id="loading"><div class="spinner"></div><p>正在解析视频...</p></div>
      <div class="error-msg" id="errorMsg"></div>
      <div class="result" id="result">
        <div class="result-card">
          <video class="result-video" id="videoPreview" controls playsinline></video>
          <div class="result-info">
            <div class="result-title" id="videoTitle">视频标题</div>
            <div class="result-author" id="videoAuthor">作者：未知</div>
            <div class="result-actions">
              <button class="btn btn-download" id="downloadBtn">下载视频</button>
            </div>
          </div>
        </div>
      </div>
    </div>
    <div class="steps">
      <p>使用方法：</p>
      <span class="step-tag">1. 打开抖音</span>
      <span class="step-tag">2. 分享 → 复制链接</span>
      <span class="step-tag">3. 粘贴到上方</span>
      <span class="step-tag">4. 点击解析</span>
    </div>
    <div class="footer">仅用于学习交流</div>
  </div>
  <script>
    const $ = id => document.getElementById(id);
    const shareUrl = $('shareUrl'), getBtn = $('getBtn'), loading = $('loading');
    const errorMsg = $('errorMsg'), result = $('result'), videoPreview = $('videoPreview');
    const videoTitle = $('videoTitle'), videoAuthor = $('videoAuthor'), downloadBtn = $('downloadBtn');
    let currentVideoUrl = '';

    getBtn.onclick = fetchVideo;
    shareUrl.onkeydown = e => e.key === 'Enter' && fetchVideo();

    async function fetchVideo() {
      const url = shareUrl.value.trim();
      if (!url) return showError('请粘贴抖音分享链接');
      if (!url.includes('douyin.com')) return showError('链接无效，需包含 douyin.com');
      hideError(); hideResult(); showLoading();
      try {
        const resp = await fetch('/api/info', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ url }) });
        const data = await resp.json();
        if (!resp.ok || !data.success) throw new Error(data.error || '解析失败');
        currentVideoUrl = data.data.videoUrl;
        videoTitle.textContent = data.data.title || '抖音视频';
        videoAuthor.textContent = '作者：' + (data.data.author || '未知');
        videoPreview.src = data.data.videoUrl + '#t=0.1';
        showResult();
      } catch(e) { showError(e.message); }
      finally { hideLoading(); }
    }

    downloadBtn.onclick = async () => {
      const url = shareUrl.value.trim();
      if (!url) return;
      if (!currentVideoUrl) {
        // 还没解析，先用下载接口获取
        downloadBtn.disabled = true; downloadBtn.textContent = '获取链接...';
        try {
          const resp = await fetch('/api/download', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ url }) });
          const data = await resp.json();
          if (!resp.ok || !data.success) throw new Error(data.error || '获取失败');
          currentVideoUrl = data.data.downloadUrl;
          if (data.data.title) videoTitle.textContent = data.data.title;
        } catch(e) { showError(e.message); downloadBtn.disabled = false; downloadBtn.textContent = '下载视频'; return; }
      }
      // 直接打开视频链接（浏览器会播放/下载）
      window.open(currentVideoUrl, '_blank');
      downloadBtn.disabled = false;
      downloadBtn.textContent = '下载视频';
    };

    function showLoading() { loading.classList.add('active'); }
    function hideLoading() { loading.classList.remove('active'); }
    function showResult() { result.classList.add('active'); }
    function hideResult() { result.classList.remove('active'); }
    function showError(m) { errorMsg.textContent = m; errorMsg.classList.add('active'); }
    function hideError() { errorMsg.classList.remove('active'); }
  </script>
</body>
</html>
HTMLEOF

# 下载后端脚本
cat > ~/douyin-downloader/server.py << 'PYEOF'
import re, os, sys, threading
import yt_dlp
from flask import Flask, request, jsonify, send_from_directory

app = Flask(__name__, static_folder='public', static_url_path='')
PORT = int(os.environ.get('PORT', 5000))
# 缓存已解析的视频信息，避免重复请求抖音
_cache = {}

def extract_url(text):
    raw = text.strip()
    for p in [r'https?://v\.douyin\.com/\S+', r'https?://www\.douyin\.com/\S+', r'https?://[^\s]*douyin\.com[^\s]*']:
        m = re.search(p, raw)
        if m: return m.group(0).rstrip('/')
    return raw

def remove_wm(url):
    return url.replace('watermark=1', 'watermark=0') if url else url

def get_best(fmts):
    c = [f for f in fmts if f.get('vcodec','none')!='none' and f.get('acodec','none')!='none']
    if not c: return None
    c.sort(key=lambda f: (f.get('height') or 0, 1 if 'h264' in (f.get('vcodec') or '') else 0), reverse=True)
    return c[0]

@app.route('/api/info', methods=['POST'])
def info():
    data = request.get_json(silent=True) or {}
    url = data.get('url','').strip()
    if not url: return jsonify({'error':'请提供链接'}),400
    try:
        url = extract_url(url)
        if url in _cache:
            return jsonify({'success':True,'data':_cache[url]})
        with yt_dlp.YoutubeDL({'quiet':True,'no_warnings':True,'no_color':True,'update_self':False,'socket_timeout':15}) as ydl:
            info = ydl.extract_info(url, download=False)
        title = re.sub(r'[\x00-\x1f\x7f]','', (info.get('title','抖音视频') or '')).strip()
        uploader = info.get('uploader','')
        author = uploader if uploader and not uploader.isdigit() else info.get('channel','未知作者')
        bf = get_best(info.get('formats',[]))
        video_url = remove_wm(bf.get('url','') if bf else '')
        _c = {'title':title,'videoUrl':video_url,'coverUrl':info.get('thumbnail',''),
            'author':author,'duration':info.get('duration'),
            'width':info.get('width'),'height':info.get('height')}
        _cache[url] = _c
        return jsonify({'success':True,'data':_c})
    except Exception as e: return jsonify({'error':str(e)}),500

@app.route('/api/download', methods=['POST'])
def download():
    data = request.get_json(silent=True) or {}
    url = data.get('url','').strip()
    if not url: return jsonify({'error':'请提供链接'}),400
    try:
        url = extract_url(url)
        if url not in _cache:
            with yt_dlp.YoutubeDL({'quiet':True,'no_warnings':True,'no_color':True,'update_self':False,'socket_timeout':15}) as ydl:
                info = ydl.extract_info(url, download=False)
            title = re.sub(r'[\x00-\x1f\x7f<>:"/\\|?*]','_', (info.get('title','douyin_video') or ''))[:50]
            bf = get_best(info.get('formats',[]))
            video_url = remove_wm(bf.get('url','') if bf else '')
            _cache[url] = {'title':title,'downloadUrl':video_url}
        else:
            title = _cache[url].get('title','douyin_video')
            video_url = _cache[url].get('downloadUrl','')
        if not video_url: return jsonify({'error':'无法获取下载地址'}),500
        return jsonify({'success':True,'data':{'downloadUrl':video_url,'title':title}})
    except Exception as e: return jsonify({'error':str(e)}),500

@app.route('/')
def index(): return send_from_directory(app.static_folder, 'index.html')

if __name__ == '__main__':
    print(f'抖音视频下载器已启动: http://localhost:{PORT}')
    app.run(host='0.0.0.0', port=PORT, debug=False)
PYEOF

# 5. 创建启动脚本
echo "[5/5] 创建启动脚本..."

cat > ~/douyin-downloader/start.sh << 'STARTEOF'
#!/data/data/com.termux/files/usr/bin/bash
echo "=============================="
echo " 抖音视频下载器"
echo "=============================="
echo ""
echo "启动服务器..."
echo ""
echo "请在手机浏览器中打开:"
echo "  http://localhost:5000"
echo ""
echo "如果要在电脑上访问:"
echo "  先运行: ifconfig"
echo "  找到你的手机 IP，然后电脑访问"
echo "  http://<手机IP>:5000"
echo ""
echo "按 Ctrl+C 停止服务器"
echo "=============================="
echo ""

cd ~/douyin-downloader
python server.py
STARTEOF

chmod +x ~/douyin-downloader/start.sh

echo ""
echo "=============================="
echo " 安装完成!"
echo "=============================="
echo ""
echo "启动方式:"
echo "  cd ~/douyin-downloader && bash start.sh"
echo ""
echo "或直接:"
echo "  python ~/douyin-downloader/server.py"
echo ""
echo "然后在手机浏览器打开 http://localhost:5000"
echo "=============================="
