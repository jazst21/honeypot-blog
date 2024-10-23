import json
from http.server import BaseHTTPRequestHandler, HTTPServer

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
        body {{ font-family: Arial, sans-serif; max-width: 800px; margin: 0 auto; padding: 20px; }}
        h1 {{ color: #333; }}
        ul {{ list-style-type: none; padding: 0; }}
        li {{ margin-bottom: 10px; }}
    </style>
</head>
<body>
    <h1>Product List</h1>
    <ul id="product-list">
        {product_list}
    </ul>
</body>
</html>
"""

class SimpleHTTPRequestHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/':
            self.send_response(200)
            self.send_header('Content-type', 'text/html')
            self.end_headers()
            product_list = "\n".join([f"<li>{product['name']} - ${product['price']}</li>" for product in products])
            html = HTML_TEMPLATE.format(product_list=product_list)
            self.wfile.write(html.encode())
        else:
            self.send_error(404, 'Not Found')

def run_server(port=8000):
    server_address = ('', port)
    httpd = HTTPServer(server_address, SimpleHTTPRequestHandler)
    print(f"Server running on port {port}")
    httpd.serve_forever()

def lambda_handler(event, context):
    # Assume it's always a GET request to the root path
    product_list = "\n".join([f"<li>{product['name']} - ${product['price']}</li>" for product in products])
    html = HTML_TEMPLATE.format(product_list=product_list)
    return {
        'statusCode': 200,
        'headers': {'Content-Type': 'text/html'},
        'body': html
    }

if __name__ == '__main__':
    run_server()
