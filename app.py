from flask import Flask, request, send_from_directory, jsonify
import requests
import os
import json
from datetime import datetime

app = Flask(__name__, static_folder='.')
JAMENDO_CLIENT_ID = os.environ.get('JAMENDO_CLIENT_ID')
JAMENDO_CLIENT_SECRET = os.environ.get('JAMENDO_CLIENT_SECRET')
PLAYLISTS_FILE = 'playlists.json'

def read_playlists():
    if not os.path.exists(PLAYLISTS_FILE):
        return {}
    try:
        with open(PLAYLISTS_FILE, 'r', encoding='utf-8') as f:
            return json.load(f)
    except Exception:
        return {}

def write_playlists(data):
    with open(PLAYLISTS_FILE, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)


@app.route('/')
def index():
    return send_from_directory('.', 'index.html')


@app.route('/api/search')
def api_search():
    q = request.args.get('q', '')
    if not q:
        return jsonify({'results': []})

    if not JAMENDO_CLIENT_ID:
        return jsonify({'error': 'Jamendo client_id tidak dikonfigurasi. Set JAMENDO_CLIENT_ID untuk mendukung audio penuh.'}), 400

    try:
        # Jamendo API - menyediakan audio streaming penuh dari lagu dengan lisensi gratis
        params = {
            'format': 'json',
            'limit': 50,
            'order': 'popularity_week',
            'client_id': JAMENDO_CLIENT_ID,
            'name': q,
            'include': 'musicinfo',
            'audioformat': 'mp32'
        }
        if JAMENDO_CLIENT_SECRET:
            params['client_secret'] = JAMENDO_CLIENT_SECRET
        res = requests.get('https://api.jamendo.com/v3.0/tracks', params=params, timeout=10)
        res.raise_for_status()
        data = res.json()
        headers = data.get('headers', {})
        if headers.get('status') == 'failed':
            return jsonify({'error': headers.get('error_message', 'Jamendo authentication gagal')}), 500
        return jsonify(data)
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@app.route('/api/playlists', methods=['GET', 'POST'])
def api_playlists():
    user = request.args.get('user', 'default')
    data = read_playlists()
    user_playlists = data.get(user, [])
    if request.method == 'GET':
        return jsonify({'playlists': user_playlists})
    # POST: create or update playlist
    body = request.get_json() or {}
    name = body.get('name')
    tracks = body.get('tracks', [])
    pid = body.get('id')
    if not name:
        return jsonify({'error': 'name required'}), 400
    if pid:
        # update existing
        for p in user_playlists:
            if p.get('id') == pid:
                p['name'] = name
                p['tracks'] = tracks
                break
    else:
        pid = f"pl_{int(datetime.utcnow().timestamp()*1000)}"
        user_playlists.append({'id': pid, 'name': name, 'tracks': tracks})
    data[user] = user_playlists
    write_playlists(data)
    return jsonify({'playlists': user_playlists})


@app.route('/api/playlists/<pid>', methods=['DELETE'])
def api_delete_playlist(pid):
    user = request.args.get('user', 'default')
    data = read_playlists()
    user_playlists = data.get(user, [])
    user_playlists = [p for p in user_playlists if p.get('id') != pid]
    data[user] = user_playlists
    write_playlists(data)
    return jsonify({'playlists': user_playlists})


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8000, debug=True)
