from flask import Flask, render_template, request, jsonify

app = Flask(__name__)

# In-memory storage for products (replace with a database in a real application)
products = [
    {"id": 1, "name": "Table", "price": 199.99},
    {"id": 2, "name": "Chair", "price": 89.99}
]

@app.route('/')
def index():
    return render_template('index.html', products=products)

@app.route('/add_product', methods=['POST'])
def add_product():
    product_id = request.form.get('id')
    product_name = request.form.get('name')
    product_price = request.form.get('price')
    
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

if __name__ == '__main__':
    app.run(debug=True)
