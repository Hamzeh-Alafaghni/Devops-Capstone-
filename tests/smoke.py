#!/usr/bin/env python3
"""End-to-end regression test against a running Compose stack or ALB."""
import concurrent.futures
import http.cookiejar
import json
import os
import urllib.error
import urllib.request
import uuid

BASE = os.environ.get('BASE_URL', 'http://127.0.0.1:5173').rstrip('/')
cookies = http.cookiejar.CookieJar()
client = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(cookies))

def call(path, method='GET', data=None, token=None, expected=200, extra=None, opener=None):
    headers = {'Content-Type': 'application/json', **(extra or {})}
    if token:
        headers['Authorization'] = 'Bearer ' + token
    request = urllib.request.Request(BASE + path, data=json.dumps(data).encode() if data is not None else None,
                                     headers=headers, method=method)
    try:
        response = (opener or client).open(request, timeout=15)
    except urllib.error.HTTPError as error:
        response = error
    with response:
        body = response.read().decode()
        assert response.status == expected, (path, response.status, body)
    return json.loads(body) if body and body[0] in '[{' else body

assert 'html' in call('/').lower()
assert 'html' in call('/orders').lower(), 'SPA deep links must resolve'
username = 'test_' + uuid.uuid4().hex[:12]
password = uuid.uuid4().hex
session = call('/api/auth/register', 'POST', {'username': username, 'password': password}, expected=201)
token = session['token']
assert call('/api/auth/me', token=token)['username'] == username
call('/api/auth/register', 'POST', {'username': username, 'password': password}, expected=409)
call('/api/auth/login', 'POST', {'username': username, 'password': 'incorrect'}, expected=401)
call('/api/auth/login', 'POST', {'username': username, 'password': password})
products = call('/api/products')['items']
product = next(p for p in products if p['stock'] >= 2)
assert call('/api/categories')
call('/api/products?q=keyboard')
call('/api/orders', expected=401)
call('/api/products/' + str(product['id']) + '/stock', 'PATCH', {'delta': 100}, expected=403)
call('/api/orders', 'POST', {'items': [{'product_id': product['id'], 'quantity': -1}]}, token, expected=400)
order = call('/api/orders', 'POST', {'items': [{'product_id': product['id'], 'quantity': 2}], 'total': 0}, token, expected=201)
assert abs(order['total'] - product['price'] * 2) < 0.001
assert call('/api/products/' + str(product['id']))['stock'] == product['stock'] - 2
assert any(item['id'] == order['id'] for item in call('/api/orders', token=token))
# Two concurrent cancellations must not restore inventory twice.
def cancel(_):
    req = urllib.request.Request(BASE + f"/api/orders/{order['id']}/cancel", data=b'{}',
        headers={'Content-Type': 'application/json', 'Authorization': 'Bearer ' + token}, method='PATCH')
    try:
        with urllib.request.urlopen(req, timeout=15) as response:
            return response.status
    except urllib.error.HTTPError as error:
        return error.code
with concurrent.futures.ThreadPoolExecutor(2) as pool:
    assert sorted(pool.map(cancel, range(2))) == [200, 409]
assert call('/api/products/' + str(product['id']))['stock'] == product['stock']
csrf = next(cookie.value for cookie in cookies if cookie.name == 'marketly_csrf_token')
call('/api/auth/refresh', 'POST', {}, expected=403)
original_refresh = next(cookie.value for cookie in cookies if cookie.name == 'marketly_refresh_token')
refreshed = call('/api/auth/refresh', 'POST', {}, extra={'X-CSRF-Token': csrf})
assert refreshed['token']
call('/api/auth/refresh', 'POST', {}, expected=401,
     extra={'X-CSRF-Token': csrf, 'Cookie': f'marketly_refresh_token={original_refresh}; marketly_csrf_token={csrf}'},
     opener=urllib.request.build_opener())
csrf = next(cookie.value for cookie in cookies if cookie.name == 'marketly_csrf_token')
old_refresh = next(cookie.value for cookie in cookies if cookie.name == 'marketly_refresh_token')
call('/api/auth/logout', 'POST', {}, extra={'X-CSRF-Token': csrf})
call('/api/auth/refresh', 'POST', {}, expected=401,
     extra={'X-CSRF-Token': csrf, 'Cookie': f'marketly_refresh_token={old_refresh}; marketly_csrf_token={csrf}'},
     opener=urllib.request.build_opener())
print('PASS: SPA, registration/login, catalog, authorization, checkout, inventory, concurrent cancellation, refresh and logout')
