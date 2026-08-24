"""
ACCOUNTS VIEWS
==============
These are the API endpoints that Flutter calls.

API ENDPOINTS:
  POST /api/auth/register/  → Create a new user account
  POST /api/auth/login/     → Get JWT access + refresh tokens
  GET  /api/auth/profile/   → Get current user's info
  PUT  /api/auth/profile/   → Update current user's profile

HOW JWT LOGIN FLOW WORKS:
  1. Flutter sends username + password to /api/auth/login/
  2. Django validates credentials, generates TWO tokens:
     - access_token (short-lived, 30 min) — for API requests
     - refresh_token (long-lived, 7 days) — to get new access tokens
  3. Flutter stores both tokens securely
  4. Every subsequent API request includes:
       Authorization: Bearer <access_token>
  5. Django reads this header, identifies the user, and processes the request
  6. When access_token expires, Flutter sends refresh_token to get a new one
"""

from rest_framework import status
from rest_framework.response import Response
from rest_framework.decorators import (
    api_view,
    permission_classes,
)
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework_simplejwt.tokens import RefreshToken

from django.contrib.auth.models import User

from .serializers import (
    UserSerializer,
    RegisterSerializer,
    LoginSerializer,
)


def get_tokens_for_user(user):
    """
    Generate JWT access + refresh tokens for a user.
    
    RefreshToken() creates a refresh token tied to this user.
    access_token is derived from the refresh token.
    
    Returns: {"refresh": "...", "access": "..."}
    
    Flutter stores these and sends the access token with every request.
    """
    refresh = RefreshToken.for_user(user)
    return {
        "refresh": str(refresh),
        "access": str(refresh.access_token),
    }


# ============================================================
# REGISTER ENDPOINT
# URL: POST /api/auth/register/
# ============================================================
# AllowAny — anyone can register, no login required
#
# Flutter sends: {"username": "...", "email": "...", "password": "..."}
# Django creates the user and returns JWT tokens + user info
# ============================================================

@api_view(["POST"])
@permission_classes([AllowAny])   # <-- no login needed to register
def register_view(request):
    """
    Register a new user.
    
    Flow:
    1. Flutter sends registration data as JSON
    2. RegisterSerializer validates it (checks unique username/email)
    3. If valid, creates User + auto-creates Profile
    4. Generates JWT tokens so user is logged in immediately
    5. Returns tokens + user data
    """
    serializer = RegisterSerializer(data=request.data)

    if serializer.is_valid():
        user = serializer.save()          # creates User + Profile
        tokens = get_tokens_for_user(user)  # generate JWT tokens

        return Response({
            "tokens": tokens,
            "user": UserSerializer(user).data,
        }, status=status.HTTP_201_CREATED)

    return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


# ============================================================
# LOGIN ENDPOINT
# URL: POST /api/auth/login/
# ============================================================
# AllowAny — anyone can attempt to login
#
# Flutter sends: {"username": "...", "password": "..."}
# Django validates and returns JWT tokens
# ============================================================

@api_view(["POST"])
@permission_classes([AllowAny])   # <-- no login needed to login (obviously!)
def login_view(request):
    """
    Login and get JWT tokens.
    
    Flow:
    1. Flutter sends username + password
    2. LoginSerializer uses Django's authenticate() to verify credentials
    3. If valid, generates JWT tokens
    4. Returns tokens + user data
    5. Flutter stores tokens and uses access_token for all future requests
    """
    serializer = LoginSerializer(data=request.data)

    if serializer.is_valid():
        user = serializer.validated_data["user"]
        tokens = get_tokens_for_user(user)

        return Response({
            "tokens": tokens,
            "user": UserSerializer(user).data,
        }, status=status.HTTP_200_OK)

    return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


# ============================================================
# PROFILE ENDPOINTS
# URL: GET/PUT /api/auth/profile/
# ============================================================
# IsAuthenticated — must be logged in (JWT token required)
#
# GET: Returns current user's info (username, email, phone, address)
# PUT: Updates profile fields (phone, address)
# ============================================================

@api_view(["GET", "PUT"])
@permission_classes([IsAuthenticated])  # <-- JWT token REQUIRED
def profile_view(request):
    """
    Get or update the logged-in user's profile.
    
    How Django identifies the user:
    1. Flutter sends: Authorization: Bearer <access_token>
    2. JWTAuthentication middleware decodes the token
    3. Finds the User matching the token's user_id
    4. Sets request.user = that User object
    5. We can now access request.user.username, request.user.profile, etc.
    """
    user = request.user  # <-- this is set by JWTAuthentication

    if request.method == "GET":
        """Return current user's data."""
        return Response(UserSerializer(user).data)

    elif request.method == "PUT":
        """
        Update profile fields.
        
        Flutter sends: {"phone": "555-0000", "address": "New Address"}
        We update only the Profile fields, not the User fields.
        """
        profile = user.profile
        profile.phone = request.data.get("phone", profile.phone)
        profile.address = request.data.get("address", profile.address)
        profile.save()

        return Response(UserSerializer(user).data)
