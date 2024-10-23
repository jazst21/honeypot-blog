def lambda_handler(event, context):
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
    # price response
    product_list = "\n".join([f"<li>{product['name']} - ${product['price']}</li>" for product in products])
    html = HTML_TEMPLATE.format(product_list=product_list)
    return {
        'statusCode': 200,
        'headers': {'Content-Type': 'text/html'},
        'body': html
    }