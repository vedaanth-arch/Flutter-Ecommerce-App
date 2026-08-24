"""
ACCOUNTS URLS
=============
Maps URLs to views.

URL Structure:
  /api/auth/register/  → register_view (POST)
  /api/auth/login/     → login_view (POST)
  /api/auth/profile/   → profile_view (GET, PUT)
  /api/auth/refresh/   → TokenRefreshView (POST) — built-in from simplejwt

The "refresh" endpoint is provided by simplejwt out of the box.
It accepts a refresh token and returns a new access token.
This is how Flutter extends sessions without re-login.
"""

from django.urls import path
from rest_framework_simplejwt.views import TokenRefreshView
from . import views

urlpatterns = [
    path("register/", views.register_view, name="register"),
    path("login/", views.login_view, name="login"),
    path("profile/", views.profile_view, name="profile"),
    # TokenRefreshView is built into simplejwt — it handles token refresh
    # Flutter sends: {"refresh": "<refresh_token>"}
    # Django returns: {"access": "<new_access_token>"}
    path("refresh/", TokenRefreshView.as_view(), name="token_refresh"),
]
