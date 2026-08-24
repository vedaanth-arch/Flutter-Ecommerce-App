"""
CART URLS
=========
Maps cart URLs to views.

URL Map:
  /api/cart/            → get_cart (GET)
  /api/cart/add/        → add_to_cart (POST)
  /api/cart/item/<id>/  → update_cart_item (PUT), remove_cart_item (DELETE)
"""

from django.urls import path
from . import views

urlpatterns = [
    path("", views.get_cart, name="get_cart"),
    path("add/", views.add_to_cart, name="add_to_cart"),
    path("item/<int:item_id>/", views.update_cart_item, name="update_cart_item"),
    path("item/<int:item_id>/remove/", views.remove_cart_item, name="remove_cart_item"),
]
