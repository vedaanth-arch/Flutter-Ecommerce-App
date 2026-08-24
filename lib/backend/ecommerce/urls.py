"""
MAIN URL CONFIGURATION
======================
This is the root URL router. It maps URL prefixes to each app's URLs.

REQUEST FLOW EXAMPLE:
  Flutter sends: POST https://myapp.com/api/auth/login/
  1. Django matches "api/auth/" → accounts/urls.py
  2. accounts/urls.py matches "login/" → login_view
  3. login_view processes the request and returns JWT tokens

FULL URL MAP:
  /api/products/       → products app (products, categories, subcategories)
  /api/auth/           → accounts app (register, login, profile, refresh)
  /api/cart/           → orders app (shopping cart)
  /api/orders/         → orders app (order placement & history)
  /admin/              → Django admin panel
"""

from django.contrib import admin
from django.urls import path, include

urlpatterns = [
    path("admin/", admin.site.urls),

    # Products API: /api/products/, /api/products/categories/, etc.
    path("api/products/", include("products.urls")),

    # Auth API: /api/auth/register/, /api/auth/login/, /api/auth/profile/
    path("api/auth/", include("accounts.urls")),

    # Cart & Orders API: /api/cart/, /api/orders/
    path("api/cart/", include("orders.cart_urls")),
    path("api/orders/", include("orders.order_urls")),
]
