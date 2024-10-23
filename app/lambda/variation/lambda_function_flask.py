import json
from flask import Flask, render_template_string
from flask.cli import ScriptInfo

app = Flask(__name__)

# In-memory storage for products (replace with a database in a real application)
products = [
    {"id": 1, "name": "Table", "price": 199.99},
    {"id": 2, "name": "Chair", "price": 89.99}
]

# HTML template as a string
HTML_TEMPLATE = """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Product List</title>
    <style>
        body { font-family: Arial, sans-serif; max-width: 800px; margin: 0 auto; padding: 20px; }
        h1 { color: #333; }
        ul { list-style-type: none; padding: 0; }
        li { margin-bottom: 10px; }
    </style>
</head>
<body>
    <h1>Product List</h1>
    <ul id="product-list">
        {% for product in products %}
        <li>{{ product.name }} - ${{ product.price }}</li>
        {% endfor %}
    </ul>
</body>
</html>
"""

@app.route('/', methods=['GET'])
def index():
    return render_template_string(HTML_TEMPLATE, products=products)

def lambda_handler(event, context):
    with app.test_client() as client:
        http_method = event['requestContext']['http']['method']
        path = event['rawPath']
        
        if http_method == 'GET' and path == '/':
            response = client.get('/')
        else:
            return {
                'statusCode': 404,
                'body': json.dumps({'error': 'Not Found'})
            }
        
        return {
            'statusCode': response.status_code,
            'headers': dict(response.headers),
            'body': response.data.decode('utf-8')
        }

if __name__ == '__main__':
    app.run(debug=True)
