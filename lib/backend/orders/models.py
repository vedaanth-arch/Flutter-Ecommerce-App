"""
ORDERS MODELS — Shopping Cart & Order System
=============================================

This file defines 4 models that make up the cart & order system:

RELATIONSHIP DIAGRAM:
┌──────────┐     ┌───────────┐     ┌──────────┐
│   User   │────▶│   Cart    │────▶│ CartItem │◀──── Product
│(Django)  │  1  │           │  1  │          │  N
└──────────┘     └───────────┘     └──────────┘

┌──────────┐     ┌───────────┐     ┌────────────┐
│   User   │────▶│   Order   │────▶│ OrderItem  │◀──── Product
│(Django)  │  1  │           │  1  │            │  N
└──────────┘     └───────────┘     └────────────┘

HOW IT WORKS:
1. Each User has ONE Cart (created automatically)
2. Cart has many CartItems (each = one product + quantity)
3. When user clicks "Checkout", Cart becomes an Order
4. Order has many OrderItems (snapshot of what was purchased)
5. Cart is cleared after checkout

WHY SEPARATE Cart AND Order?
- Cart is temporary (user is still shopping)
- Order is permanent (historical record)
- Products might change price after purchase, so OrderItem
  stores the price at time of purchase (not a reference to Product.price)
"""

from django.db import models
from django.contrib.auth.models import User
from products.models import Product


class Cart(models.Model):
    """
    Shopping cart — one per user.
    
    Created automatically when user registers (via signal, like Profile).
    Each user can only have ONE cart.
    
    Fields:
      user     — the owner of this cart
      created  — when the cart was created
      updated  — last time something changed in the cart
    """
    user = models.OneToOneField(
        User,
        on_delete=models.CASCADE,
        related_name="cart"   # user.cart gives this cart
    )
    created = models.DateTimeField(auto_now_add=True)
    updated = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"Cart of {self.user.username}"

    @property
    def total_price(self):
        """
        Calculate total price of all items in the cart.
        
        Goes through each CartItem, multiplies price × quantity,
        and sums them up.
        
        Example: 2 × $10 + 1 × $25 = $45
        """
        return sum(
            item.product.price * item.quantity
            for item in self.items.all()
        )

    @property
    def total_items(self):
        """Count total number of items (sum of all quantities)."""
        return sum(item.quantity for item in self.items.all())


class CartItem(models.Model):
    """
    A single item inside a cart.
    
    Example:
      CartItem(product=Product("Shoes"), quantity=2)
      → "2 pairs of Shoes in the cart"
    
    Fields:
      cart     — which cart this item belongs to
      product  — which product
      quantity — how many (minimum 1)
      added    — when this item was added
    """
    cart = models.ForeignKey(
        Cart,
        on_delete=models.CASCADE,
        related_name="items"   # cart.items gives all CartItems
    )
    product = models.ForeignKey(
        Product,
        on_delete=models.CASCADE
    )
    quantity = models.PositiveIntegerField(default=1)
    added = models.DateTimeField(auto_now_add=True)

    class Meta:
        # Each product can appear only ONCE per cart.
        # To increase quantity, we update the existing CartItem
        # instead of creating a new one.
        unique_together = ("cart", "product")

    def __str__(self):
        return f"{self.quantity}× {self.product.name} in {self.cart}"


class Order(models.Model):
    """
    A completed purchase — created when user checks out.
    
    Unlike Cart, Order is PERMANENT. It records what the user bought,
    when, and for how much. Even if the product price changes later,
    the Order preserves the original price.
    
    Fields:
      user         — who placed the order
      total_price  — total cost (calculated at checkout time)
      status       — pending → confirmed → shipped → delivered
      created      — when the order was placed
      address      — shipping address
    """
    
    # Order status choices — Django's way of creating dropdown options
    STATUS_CHOICES = [
        ("pending", "Pending"),          # just placed
        ("confirmed", "Confirmed"),      # seller acknowledged
        ("shipped", "Shipped"),          # on the way
        ("delivered", "Delivered"),      # arrived
        ("cancelled", "Cancelled"),      # user or seller cancelled
    ]

    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name="orders"   # user.orders gives all user's orders
    )
    total_price = models.DecimalField(
        max_digits=10,
        decimal_places=2
    )
    status = models.CharField(
        max_length=20,
        choices=STATUS_CHOICES,
        default="pending"
    )
    address = models.TextField(blank=True, default="")
    created = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Order #{self.id} by {self.user.username} ({self.status})"


class OrderItem(models.Model):
    """
    A snapshot of one product inside a completed order.
    
    IMPORTANT: This stores the price at time of purchase!
    
    Why? Because Product.price might change later (sale, price increase).
    The OrderItem preserves what the user actually paid.
    
    Example:
      OrderItem(order=Order#1, product="Shoes", price=$80, quantity=2)
      → Even if Shoes now cost $100, this record shows $80 × 2 = $160
    """
    order = models.ForeignKey(
        Order,
        on_delete=models.CASCADE,
        related_name="items"   # order.items gives all OrderItems
    )
    product = models.ForeignKey(
        Product,
        on_delete=models.CASCADE
    )
    price = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        help_text="Price at time of purchase"
    )
    quantity = models.PositiveIntegerField(default=1)

    def __str__(self):
        return f"{self.quantity}× {self.product.name} in Order #{self.order.id}"

    @property
    def subtotal(self):
        """Price × Quantity for this line item."""
        return self.price * self.quantity


# ============================================================
# SIGNAL: Auto-create Cart when a new User is registered
# ============================================================
# Same pattern as Profile in accounts/models.py.

from django.db.models.signals import post_save
from django.dispatch import receiver


@receiver(post_save, sender=User)
def create_user_cart(sender, instance, created, **kwargs):
    """Auto-create an empty Cart when a new User is created."""
    if created:
        Cart.objects.create(user=instance)
