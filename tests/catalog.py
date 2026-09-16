"""Run inside catalog-service against PostgreSQL; checks admin writes and row locks."""
from concurrent.futures import ThreadPoolExecutor
import datetime
import jwt
import app

client = app.app.test_client()
token = jwt.encode({'sub': 'regression-admin', 'role': 'admin', 'type': 'access',
                    'exp': datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(minutes=1)},
                   app.SHARED_SECRET, algorithm='HS256')
headers = {'Authorization': 'Bearer ' + token}
assert client.post('/api/products', json={'name': 'test', 'price': 1}).status_code == 403
response = client.post('/api/products', json={'name': 'Regression product', 'price': 12.5, 'stock': 1}, headers=headers)
assert response.status_code == 201, response.json
product_id = response.json['id']
path = f'/api/products/{product_id}'
try:
    assert client.put(path, json={'price': 15}, headers=headers).json['price'] == 15
    def reserve(_):
        with app.app.test_client() as isolated:
            return isolated.patch(path + '/stock', json={'delta': -1},
                                  headers={'X-Service-Secret': app.SHARED_SECRET}).status_code
    with ThreadPoolExecutor(2) as executor:
        assert sorted(executor.map(reserve, range(2))) == [200, 409]
    assert client.get(path).json['stock'] == 0
finally:
    assert client.delete(path, headers=headers).status_code == 200
print('PASS: PostgreSQL product creation/RETURNING, admin update/delete, concurrent stock reservation')
