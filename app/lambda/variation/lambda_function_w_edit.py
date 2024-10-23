import json
from flask import Flask, render_template_string, request, jsonify
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
    <title>Product Management</title>
    <script src="https://cdn.jsdelivr.net/npm/axios/dist/axios.min.js"></script>
    <style>
        body { font-family: Arial, sans-serif; max-width: 800px; margin: 0 auto; padding: 20px; }
        h1 { color: #333; }
        ul { list-style-type: none; padding: 0; }
        li { margin-bottom: 10px; }
        form { margin-top: 20px; }
        input { margin-bottom: 10px; }
    </style>
</head>
<body>
    <h1>Product Management</h1>
    <h2>Product List</h2>
    <ul id="product-list">
        {% for product in products %}
        <li>{{ product.name }} - ${{ product.price }}</li>
        {% endfor %}
    </ul>
    <h2>Add New Product</h2>
    <form id="add-product-form">
        <input type="number" id="product-id" placeholder="Product ID" required><br>
        <input type="text" id="product-name" placeholder="Product Name" required><br>
        <input type="number" id="product-price" placeholder="Product Price" step="0.01" required><br>
        <button type="submit">Add Product</button>
    </form>
    <script>
        document.getElementById('add-product-form').addEventListener('submit', function(e) {
            e.preventDefault();
            const id = document.getElementById('product-id').value;
            const name = document.getElementById('product-name').value;
            const price = document.getElementById('product-price').value;
            
            axios.post('/add_product', {
                id: id,
                name: name,
                price: price
            })
            .then(function (response) {
                if (response.data.success) {
                    const newProduct = response.data.product;
                    const productList = document.getElementById('product-list');
                    const newItem = document.createElement('li');
                    newItem.textContent = `${newProduct.name} - $${newProduct.price}`;
                    productList.appendChild(newItem);
                    document.getElementById('add-product-form').reset();
                } else {
                    alert('Error: ' + response.data.error);
                }
            })
            .catch(function (error) {
                console.error('Error:', error);
                alert('An error occurred while adding the product.');
            });
        });
    </script>
</body>
</html>
"""

@app.route('/', methods=['GET'])
def index():
    return render_template_string(HTML_TEMPLATE, products=products)

@app.route('/add_product', methods=['POST'])
def add_product():
    data = json.loads(request.data)
    product_id = data.get('id')
    product_name = data.get('name')
    product_price = data.get('price')
    
    if product_id and product_name and product_price:
        try:
            new_product = {
                "id": int(product_id),
                "name": product_name,
                "price": float(product_price)
            }
            products.append(new_product)
            return jsonify({"success": True, "product": new_product})
        except ValueError:
            return jsonify({"success": False, "error": "Invalid input: ID must be an integer and price must be a number"}), 400
    else:
        return jsonify({"success": False, "error": "Missing required fields"}), 400

def lambda_handler(event, context):
    with app.test_client() as client:
        http_method = event['requestContext']['http']['method']
        path = event['rawPath']
        
        if http_method == 'GET' and path == '/':
            response = client.get('/')
        elif http_method == 'POST' and path == '/add_product':
            response = client.post('/add_product', data=event['body'])
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
