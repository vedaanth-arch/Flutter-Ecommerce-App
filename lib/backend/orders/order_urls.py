"""
ORDER URLS
==========
Maps order URLs to views.

URL Map:
  /api/orders/              → list_orders (GET)
  /api/orders/checkout/     → checkout (POST)
  /api/orders/<id>/         → get_order (GET)
"""

from django.urls import path
from . import views

urlpatterns = [
    path("", views.list_orders, name="list_orders"),
    path("checkout/", views.checkout, name="checkout"),
    path("<int:order_id>/", views.get_order, name="get_order"),
]
