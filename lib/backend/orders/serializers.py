"""
ORDERS SERIALIZERS
==================
Converts Cart/Order models to JSON for Flutter, and vice versa.

JSON EXAMPLES:

Cart response:
{
  "id": 1,
  "total_price": "45.00",
  "total_items": 3,
  "items": [
    {"id": 1, "product": 5, "product_name": "Shoes", "quantity": 2, "subtotal": "20.00"},
    {"id": 2, "product": 8, "product_name": "Hat", "quantity": 1, "subtotal": "25.00"}
  ]
}

Add to cart request:
{"product": 5, "quantity": 2}
"""

from rest_framework import serializers
from .models import Cart, CartItem, Order, OrderItem
from products.models import Product


# ============================================================
# CART SERIALIZERS
# ============================================================

class CartItemSerializer(serializers.ModelSerializer):
    """
    Serializes a single cart item.
    
    Includes extra computed fields:
      - product_name: human-readable product name (from Product model)
      - subtotal: price × quantity
    
    read_only fields are computed server-side, not sent by Flutter.
    """
    product_name = serializers.CharField(
        source="product.name",
        read_only=True
    )
    product_price = serializers.DecimalField(
        source="product.price",
        max_digits=10,
        decimal_places=2,
        read_only=True
    )
    subtotal = serializers.SerializerMethodField()

    class Meta:
        model = CartItem
        fields = [
            "id",
            "product",          # product ID (Flutter sends this)
            "product_name",     # product name (computed, read-only)
            "product_price",    # product price (computed, read-only)
            "quantity",
            "subtotal",         # price × quantity (computed, read-only)
        ]

    def get_subtotal(self, obj):
        """Calculate subtotal = product price × quantity."""
        return str(obj.product.price * obj.quantity)


class CartSerializer(serializers.ModelSerializer):
    """
    Serializes the entire cart with all its items.
    
    items is nested — each item is serialized with CartItemSerializer.
    total_price and total_items are computed properties from the model.
    """
    items = CartItemSerializer(many=True, read_only=True)
    total_price = serializers.SerializerMethodField()
    total_items = serializers.SerializerMethodField()

    class Meta:
        model = Cart
        fields = ["id", "items", "total_price", "total_items"]

    def get_total_price(self, obj):
        return str(obj.total_price)

    def get_total_items(self, obj):
        return obj.total_items


class AddToCartSerializer(serializers.Serializer):
    """
    Validates data when Flutter adds a product to the cart.
    
    Flutter sends: {"product": 5, "quantity": 2}
    
    This serializer:
    1. Validates that product ID exists in the database
    2. Validates that quantity is at least 1
    """
    product = serializers.IntegerField()
    quantity = serializers.IntegerField(min_value=1, default=1)

    def validate_product(self, value):
        """Check that the product exists."""
        if not Product.objects.filter(id=value).exists():
            raise serializers.ValidationError("Product not found.")
        return value


# ============================================================
# ORDER SERIALIZERS
# ============================================================

class OrderItemSerializer(serializers.ModelSerializer):
    """Serializes a single item in a completed order."""
    product_name = serializers.CharField(
        source="product.name",
        read_only=True
    )
    subtotal = serializers.SerializerMethodField()

    class Meta:
        model = OrderItem
        fields = ["id", "product", "product_name", "price", "quantity", "subtotal"]

    def get_subtotal(self, obj):
        return str(obj.subtotal)


class OrderSerializer(serializers.ModelSerializer):
    """
    Serializes a complete order with all its items.
    
    Includes status display (e.g., "Pending", "Shipped")
    and nested items.
    """
    items = OrderItemSerializer(many=True, read_only=True)
    status_display = serializers.CharField(
        source="get_status_display",
        read_only=True
    )

    class Meta:
        model = Order
        fields = [
            "id",
            "total_price",
            "status",
            "status_display",
            "address",
            "created",
            "items",
        ]
