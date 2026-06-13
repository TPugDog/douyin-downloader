"""
抖音视频下载服务 - Python 版 (使用 yt-dlp)
用法: python server.py
然后浏览器打开 http://localhost:3000
"""

import re
import json
import os
import sys
import tempfile
import urllib.parse
import uuid
import requests

import yt_dlp
from flask import Flask, request, jsonify, send_from_directory, Response, send_file

app = Flask(__name__, static_folder='public', static_url_path='')

PORT = int(os.environ.get('PORT', 3000))


def extract_url(text):
    """从杂乱的粘贴文本中提取抖音 URL"""
    raw = text.strip()
    patterns = [
        r'https?://v\.douyin\.com/\S+',
        r'https?://www\.douyin\.com/\S+',
        r'https?://[^\s]*douyin\.com[^\s]*',
        r'https?://[^\s]*douyinvod\.com[^\s]*',
        r'https?://[^\s]*amemv\.com[^\s]*',
    ]
    for p in patterns:
        m = re.search(p, raw)
        if m:
            return m.group(0).rstrip('/')
    return raw


def get_ydl_opts():
    """yt-dlp 通用配置"""
    return {
        'quiet': True,
        'no_warnings': True,
        'extract_flat': False,
        'no_color': True,
    }


def remove_watermark(url):
    """将视频URL中的 watermark=1 替换为 watermark=0 以去水印"""
    if not url:
        return url
    return url.replace('watermark=1', 'watermark=0')


def get_best_format(formats):
    """从格式列表中选最佳画质（优先h264，取最高分辨率）"""
    candidates = [f for f in formats if f.get('vcodec', 'none') != 'none' and f.get('acodec', 'none') != 'none']
    if not candidates:
        return None

    # 按分辨率降序、h264优先
    def sort_key(f):
        height = f.get('height') or 0
        is_h264 = 1 if 'h264' in (f.get('vcodec') or '') else 0
        return (height, is_h264)

    candidates.sort(key=sort_key, reverse=True)
    return candidates[0]


@app.route('/api/info', methods=['POST'])
def api_info():
    """获取视频信息（标题、作者、时长、封面）"""
    data = request.get_json(silent=True) or {}
    url = data.get('url', '').strip()
    if not url:
        return jsonify({'error': '请提供抖音分享链接'}), 400

    try:
        url = extract_url(url)
        ydl_opts = get_ydl_opts()
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(url, download=False)

        # 提取关键信息
        title = info.get('title', '抖音视频') or '抖音视频'
        title = re.sub(r'[\x00-\x1f\x7f]', '', title).strip()

        # 获取作者
        uploader = info.get('uploader', '')
        if uploader and not uploader.isdigit():
            author = uploader
        else:
            author = info.get('channel', info.get('creator', info.get('channel_id', '未知作者')))

        # 找最佳画质的格式并去水印
        formats = info.get('formats', [])
        best_format = get_best_format(formats)
        if not best_format and formats:
            best_format = formats[-1]

        video_url = remove_watermark(best_format.get('url', '') if best_format else '')

        # 获取封面
        thumbnail = info.get('thumbnail', '')

        # 获取视频尺寸
        width = info.get('width') or (best_format.get('width') if best_format else None)
        height = info.get('height') or (best_format.get('height') if best_format else None)

        # 格式信息
        ext = best_format.get('ext', 'mp4') if best_format else 'mp4'
        filesize = best_format.get('filesize') or best_format.get('filesize_approx') if best_format else None

        return jsonify({
            'success': True,
            'data': {
                'title': title,
                'videoUrl': video_url,
                'coverUrl': thumbnail,
                'author': author,
                'duration': info.get('duration'),
                'width': width,
                'height': height,
                'ext': ext,
                'filesize': filesize,
            }
        })

    except Exception as e:
        print(f'获取视频信息失败: {e}')
        return jsonify({'error': str(e) or '获取视频信息失败，请检查链接是否正确'}), 500


@app.route('/api/download', methods=['POST'])
def api_download():
    """下载视频"""
    data = request.get_json(silent=True) or {}
    url = data.get('url', '').strip()
    if not url:
        return jsonify({'error': '请提供抖音分享链接'}), 400

    try:
        url = extract_url(url)

        # 先获取视频信息
        ydl_opts = get_ydl_opts()
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(url, download=False)

        title = info.get('title', '抖音视频')
        title = re.sub(r'[\x00-\x1f\x7f<>:"/\\|?*]', '_', title).strip()[:50] or 'douyin_video'

        # 获取最佳格式的 URL 并去水印
        formats = info.get('formats', [])
        best_format = get_best_format(formats)
        best_url = remove_watermark(best_format.get('url', '')) if best_format else None

        if not best_url:
            return jsonify({'error': '无法获取视频下载地址'}), 500

        print(f'正在下载视频: {title}')

        # 使用 requests 流式代理下载视频
        headers = {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            'Referer': 'https://www.douyin.com/',
        }
        video_resp = requests.get(best_url, headers=headers, stream=True, timeout=60)

        content_type = video_resp.headers.get('content-type', 'video/mp4')
        content_length = video_resp.headers.get('content-length')

        def generate():
            for chunk in video_resp.iter_content(chunk_size=8192):
                if chunk:
                    yield chunk

        resp_headers = {
            'Content-Type': content_type,
            'Content-Disposition': f'attachment; filename="{urllib.parse.quote(title)}.mp4"',
            'Accept-Ranges': 'bytes',
            'Cache-Control': 'no-cache',
        }
        if content_length:
            resp_headers['Content-Length'] = content_length

        return Response(generate(), headers=resp_headers)

    except Exception as e:
        print(f'下载视频失败: {e}')
        return jsonify({'error': str(e) or '下载视频失败，请稍后重试'}), 500


@app.route('/')
def index():
    return send_from_directory(app.static_folder, 'index.html')


@app.errorhandler(404)
def not_found(e):
    return send_from_directory(app.static_folder, 'index.html')


if __name__ == '__main__':
    sys.stdout = __import__('io').TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
    print(f'抖音视频下载服务已启动: http://localhost:{PORT}')
    print(f'在浏览器中打开以上地址即可使用')
    app.run(host='0.0.0.0', port=PORT, debug=True)
