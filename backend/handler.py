"""AWS Lambda handler using apig-wsgi."""
from apig_wsgi import make_lambda_handler
from app import create_app

# Create Flask app
app = create_app()

# Create Lambda handler (WSGI adapter for API Gateway)
handler = make_lambda_handler(app)


# For local development
if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)
