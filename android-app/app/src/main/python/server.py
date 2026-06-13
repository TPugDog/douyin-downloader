"""
抖音视频下载服务 - Android 内嵌版 (使用 yt-dlp)
通过 Chaquopy 在 Android 上运行
"""

import re
import os
import sys
import threading
import urllib.parse
import json as json_module

import yt_dlp
from flask import Flask, request, jsonify, send_from_directory, Response

app = Flask(__name__)

# 在 Android 上由 MainActivity 传入 filesDir
STATIC_DIR = None


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


def remove_watermark(url):
    if not url:
        return url
    return url.replace('watermark=1', 'watermark=0')


def get_best_format(formats):
    candidates = [f for f in formats if f.get('vcodec', 'none') != 'none' and f.get('acodec', 'none') != 'none']
    if not candidates:
        return None
    def sort_key(f):
        height = f.get('height') or 0
        is_h264 = 1 if 'h264' in (f.get('vcodec') or '') else 0
        return (height, is_h264)
    candidates.sort(key=sort_key, reverse=True)
    return candidates[0]


@app.route('/api/info', methods=['POST'])
def api_info():
    data = request.get_json(silent=True) or {}
    url = data.get('url', '').strip()
    if not url:
        return jsonify({'error': '请提供抖音分享链接'}), 400

    try:
        url = extract_url(url)
        with yt_dlp.YoutubeDL({'quiet': True, 'no_warnings': True, 'no_color': True}) as ydl:
            info = ydl.extract_info(url, download=False)

        title = info.get('title', '抖音视频') or '抖音视频'
        title = re.sub(r'[\x00-\x1f\x7f]', '', title).strip()

        uploader = info.get('uploader', '')
        if uploader and not uploader.isdigit():
            author = uploader
        else:
            author = info.get('channel', info.get('creator', '未知作者'))

        formats = info.get('formats', [])
        best_format = get_best_format(formats)
        if not best_format and formats:
            best_format = formats[-1]

        video_url = remove_watermark(best_format.get('url', '') if best_format else '')
        thumbnail = info.get('thumbnail', '')
        width = info.get('width') or (best_format.get('width') if best_format else None)
        height = info.get('height') or (best_format.get('height') if best_format else None)
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
        return jsonify({'error': str(e) or '获取视频信息失败'}), 500


@app.route('/api/download', methods=['POST'])
def api_download():
    """返回视频直链，前端通过 AndroidBridge 下载"""
    data = request.get_json(silent=True) or {}
    url = data.get('url', '').strip()
    if not url:
        return jsonify({'error': '请提供抖音分享链接'}), 400

    try:
        url = extract_url(url)
        with yt_dlp.YoutubeDL({'quiet': True, 'no_warnings': True, 'no_color': True}) as ydl:
            info = ydl.extract_info(url, download=False)

        title = info.get('title', '抖音视频')
        title = re.sub(r'[\x00-\x1f\x7f<>:"/\\|?*]', '_', title).strip()[:50] or 'douyin_video'

        formats = info.get('formats', [])
        best_format = get_best_format(formats)
        best_url = remove_watermark(best_format.get('url', '')) if best_format else None

        if not best_url:
            return jsonify({'error': '无法获取视频下载地址'}), 500

        return jsonify({
            'success': True,
            'data': {
                'downloadUrl': best_url,
                'title': title,
            }
        })
    except Exception as e:
        return jsonify({'error': str(e) or '下载视频失败'}), 500


@app.route('/')
def index():
    if STATIC_DIR:
        idx_path = os.path.join(STATIC_DIR, 'index.html')
        if os.path.exists(idx_path):
            with open(idx_path, 'r', encoding='utf-8') as f:
                return f.read(), 200, {'Content-Type': 'text/html; charset=utf-8'}
    return 'Frontend not found', 404


_app_thread = None


def start_server(port, files_dir=None):
    """启动 Flask 服务器（在后台线程中运行），由 Chaquopy 调用"""
    global _app_thread, STATIC_DIR
    STATIC_DIR = files_dir
    if _app_thread and _app_thread.is_alive():
        return True

    def run():
        app.run(host='127.0.0.1', port=port, debug=False, use_reloader=False)

    _app_thread = threading.Thread(target=run, daemon=True)
    _app_thread.start()
    return True


def stop_server():
    """停止服务器"""
    import requests as req
    try:
        req.get('http://127.0.0.1:8765/shutdown', timeout=1)
    except:
        pass
