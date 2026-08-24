"""
ORDERS VIEWS — Cart & Order API Endpoints
==========================================

CART API ENDPOINTS:
  GET    /api/cart/          → View current cart with all items
  POST   /api/cart/add/      → Add a product to cart (or increase quantity)
  PUT    /api/cart/item/<id>/ → Update quantity of a cart item
  DELETE /api/cart/item/<id>/ → Remove an item from cart

ORDER API ENDPOINTS:
  POST   /api/orders/checkout/ → Place order (convert cart → order)
  GET    /api/orders/          → List all user's orders
  GET    /api/orders/<id>/     → Get details of a specific order

HOW THE CART WORKS:
  ┌──────────────────────────────────────────────────────────┐
  │ User taps "Add to Cart" on product card                  │
  │     ↓                                                    │
  │ Flutter sends POST /api/cart/add/ {"product": 5, "qty": 1} │
  │     ↓                                                    │
  │ Django checks: Is there already a CartItem for this      │
  │   product in this user's cart?                           │
  │     ↓                                                    │
  │   YES → increase quantity by 1 (don't create duplicate)  │
  │   NO  → create new CartItem with quantity 1              │
  │     ↓                                                    │
  │ Return updated cart JSON                                 │
  └──────────────────────────────────────────────────────────┘

HOW CHECKOUT WORKS:
  ┌──────────────────────────────────────────────────────────┐
  │ User taps "Checkout" in cart page                        │
  │     ↓                                                    │
  │ Flutter sends POST /api/orders/checkout/ {"address": "..."} │
  │     ↓                                                    │
  │ Django: 1. Get user's cart                               │
  │         2. Create Order with total price                 │
  │         3. Create OrderItem for each CartItem            │
  │            (stores current price as snapshot!)           │
  │         4. Clear the cart (delete all CartItems)         │
  │         5. Return the new Order                          │
  └──────────────────────────────────────────────────────────┘
"""

from rest_framework import status
from rest_framework.response import Response
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated

from .models import Cart, CartItem, Order, OrderItem
from .serializers import (
    CartSerializer,
    AddToCartSerializer,
    OrderSerializer,
)


# ============================================================
# HELPER: Get or create the user's cart
# ============================================================
# Every user has exactly ONE cart. This function finds it,
# or creates one if it doesn't exist (safety net).

def get_user_cart(user):
    cart, created = Cart.objects.get_or_create(user=user)
    return cart


# ============================================================
# GET CART
# URL: GET /api/cart/
# ============================================================
# Returns the user's cart with all items, total price, total count.
#
# Flutter uses this to display the cart page.

@api_view(["GET"])
@permission_classes([IsAuthenticated])
def get_cart(request):
    """
    Return the current user's cart.
    
    Flow:
    1. JWT middleware identifies the user from the token
    2. We find (or create) their cart
    3. Serialize cart with all items
    4. Return JSON
    """
    cart = get_user_cart(request.user)
    serializer = CartSerializer(cart)
    return Response(serializer.data)


# ============================================================
# ADD TO CART
# URL: POST /api/cart/add/
# ============================================================
# Adds a product to the cart. If already in cart, increases quantity.
#
# Flutter sends: {"product": 5, "quantity": 2}
# Django returns: updated cart JSON

@api_view(["POST"])
@permission_classes([IsAuthenticated])
def add_to_cart(request):
    """
    Add a product to the user's cart.
    
    Flow:
    1. Validate input (product ID + quantity)
    2. Get user's cart
    3. Check if this product is already in the cart
       - YES: increase quantity (don't duplicate!)
       - NO: create new CartItem
    4. Return updated cart
    """
    serializer = AddToCartSerializer(data=request.data)
    if not serializer.is_valid():
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    product_id = serializer.validated_data["product"]
    quantity = serializer.validated_data["quantity"]

    cart = get_user_cart(request.user)

    # Check if item already exists in cart
    cart_item, created = CartItem.objects.get_or_create(
        cart=cart,
        product_id=product_id,
        defaults={"quantity": quantity}
    )

    if not created:
        # Item already existed — just increase quantity
        cart_item.quantity += quantity
        cart_item.save()

    # Return the updated cart
    cart_serializer = CartSerializer(cart)
    return Response(cart_serializer.data, status=status.HTTP_200_OK)


# ============================================================
# UPDATE CART ITEM QUANTITY
# URL: PUT /api/cart/item/<item_id>/
# ============================================================
# Changes the quantity of a specific cart item.
#
# Flutter sends: {"quantity": 5}
# Use case: user taps +/- buttons in the cart page

@api_view(["PUT"])
@permission_classes([IsAuthenticated])
def update_cart_item(request, item_id):
    """
    Update the quantity of a cart item.
    
    Flow:
    1. Find the CartItem by ID
    2. Verify it belongs to the current user's cart (security!)
    3. Update quantity
    4. If quantity is 0, delete the item
    5. Return updated cart
    """
    try:
        cart_item = CartItem.objects.get(
            id=item_id,
            cart__user=request.user  # security: only modify own cart
        )
    except CartItem.DoesNotExist:
        return Response(
            {"error": "Cart item not found"},
            status=status.HTTP_404_NOT_FOUND
        )

    quantity = request.data.get("quantity", 1)

    if quantity <= 0:
        # Quantity 0 or less = remove the item
        cart_item.delete()
    else:
        cart_item.quantity = quantity
        cart_item.save()

    cart = get_user_cart(request.user)
    serializer = CartSerializer(cart)
    return Response(serializer.data)


# ============================================================
# REMOVE CART ITEM
# URL: DELETE /api/cart/item/<item_id>/
# ============================================================
# Removes a product from the cart entirely.

@api_view(["DELETE"])
@permission_classes([IsAuthenticated])
def remove_cart_item(request, item_id):
    """
    Remove an item from the cart.
    
    Flow:
    1. Find the CartItem
    2. Verify ownership
    3. Delete it
    4. Return updated cart
    """
    try:
        cart_item = CartItem.objects.get(
            id=item_id,
            cart__user=request.user
        )
        cart_item.delete()
    except CartItem.DoesNotExist:
        return Response(
            {"error": "Cart item not found"},
            status=status.HTTP_404_NOT_FOUND
        )

    cart = get_user_cart(request.user)
    serializer = CartSerializer(cart)
    return Response(serializer.data)


# ============================================================
# CHECKOUT — Convert Cart to Order
# URL: POST /api/orders/checkout/
# ============================================================
# This is the most important endpoint. It converts a shopping
# cart into a permanent order.
#
# Flutter sends: {"address": "123 Main St, City"}
# Django creates Order + OrderItems, clears cart, returns Order.

@api_view(["POST"])
@permission_classes([IsAuthenticated])
def checkout(request):
    """
    Place an order from the current cart.
    
    Flow:
    1. Get user's cart
    2. Validate cart is not empty
    3. Calculate total price
    4. Create Order record
    5. For each CartItem, create an OrderItem
       (stores the CURRENT price as a snapshot!)
    6. Clear the cart (delete all CartItems)
    7. Return the new Order
    
    WHY SNAPSHOT THE PRICE?
    If Shoes cost $80 today but $100 tomorrow, the OrderItem
    still shows $80 — that's what the user actually paid.
    """
    cart = get_user_cart(request.user)

    if not cart.items.exists():
        return Response(
            {"error": "Cart is empty"},
            status=status.HTTP_400_BAD_REQUEST
        )

    # 1. Create the Order
    order = Order.objects.create(
        user=request.user,
        total_price=cart.total_price,
        address=request.data.get("address", ""),
    )

    # 2. Create OrderItems from CartItems
    # IMPORTANT: We store the current product price in OrderItem.price
    # This is a "snapshot" — if the product price changes later,
    # the OrderItem still records what was paid.
    for cart_item in cart.items.all():
        OrderItem.objects.create(
            order=order,
            product=cart_item.product,
            price=cart_item.product.price,  # <-- snapshot!
            quantity=cart_item.quantity,
        )

    # 3. Clear the cart
    cart.items.all().delete()

    # 4. Return the order
    serializer = OrderSerializer(order)
    return Response(serializer.data, status=status.HTTP_201_CREATED)


# ============================================================
# LIST ORDERS
# URL: GET /api/orders/
# ============================================================
# Returns all orders placed by the current user.

@api_view(["GET"])
@permission_classes([IsAuthenticated])
def list_orders(request):
    """
    Get all orders for the current user.
    
    Ordered by most recent first.
    """
    orders = Order.objects.filter(user=request.user).order_by("-created")
    serializer = OrderSerializer(orders, many=True)
    return Response(serializer.data)


# ============================================================
# GET SINGLE ORDER
# URL: GET /api/orders/<order_id>/
# ============================================================

@api_view(["GET"])
@permission_classes([IsAuthenticated])
def get_order(request, order_id):
    """
    Get details of a specific order.
    
    Security: only returns the order if it belongs to the current user.
    """
    try:
        order = Order.objects.get(
            id=order_id,
            user=request.user  # security: can't view other users' orders
        )
    except Order.DoesNotExist:
        return Response(
            {"error": "Order not found"},
            status=status.HTTP_404_NOT_FOUND
        )

    serializer = OrderSerializer(order)
    return Response(serializer.data)
