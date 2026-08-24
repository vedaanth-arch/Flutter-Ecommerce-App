"""
ACCOUNTS MODELS
===============
We use Django's built-in User model for authentication (username, email, password).
Django already handles hashing passwords, checking credentials, etc.

We ADD a Profile model to store extra info (phone, address) that the User model
doesn't have by default. This is called a "one-to-one" relationship — each User
gets exactly one Profile.

HOW IT WORKS:
- User registers → Django creates a User record
- Profile is auto-created via a "signal" (see below)
- When Flutter calls /api/auth/profile/, we return both User + Profile data
"""

from django.db import models
from django.contrib.auth.models import User
from django.db.models.signals import post_save
from django.dispatch import receiver


class Profile(models.Model):
    """
    One-to-one extension of Django's User model.
    Stores extra ecommerce-relevant info: phone and shipping address.
    """
    user = models.OneToOneField(
        User,
        on_delete=models.CASCADE,
        related_name="profile"   # user.profile gives us this Profile
    )
    phone = models.CharField(max_length=20, blank=True, default="")
    address = models.TextField(blank=True, default="")

    def __str__(self):
        return f"Profile of {self.user.username}"


# ============================================================
# SIGNALS — auto-create Profile when a new User is created
# ============================================================
# A "signal" is Django's way of saying: "When X happens, also do Y."
#
# post_save means: "After a User is saved to the database..."
# ...also create a Profile for that user.
#
# Without this, we'd have to manually create a Profile every time
# someone registers. The signal does it automatically.
# ============================================================

@receiver(post_save, sender=User)
def create_user_profile(sender, instance, created, **kwargs):
    """Auto-create Profile when a new User is created."""
    if created:
        Profile.objects.create(user=instance)


@receiver(post_save, sender=User)
def save_user_profile(sender, instance, **kwargs):
    """Auto-save Profile when User is updated."""
    instance.profile.save()
