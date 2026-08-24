"""
ACCOUNTS SERIALIZERS
====================
Serializers convert complex Django objects (User, Profile) into JSON
that Flutter can understand, and vice versa (JSON from Flutter → Django objects).

We have 3 serializers:
1. RegisterSerializer — validates registration data & creates new users
2. UserSerializer — converts existing User+Profile to JSON for responses
3. LoginSerializer — validates login credentials
"""

from rest_framework import serializers
from django.contrib.auth.models import User
from django.contrib.auth import authenticate
from .models import Profile


class ProfileSerializer(serializers.ModelSerializer):
    """
    Converts Profile model to JSON.
    Example output: {"phone": "555-1234", "address": "123 Main St"}
    """
    class Meta:
        model = Profile
        fields = ["phone", "address"]


class UserSerializer(serializers.ModelSerializer):
    """
    Converts User + Profile to JSON for API responses.
    Example output:
    {
        "id": 1,
        "username": "john",
        "email": "john@example.com",
        "profile": {"phone": "555-1234", "address": "123 Main St"}
    }
    """
    profile = ProfileSerializer(read_only=True)   # <-- nests Profile inside User

    class Meta:
        model = User
        fields = ["id", "username", "email", "profile"]


class RegisterSerializer(serializers.Serializer):
    """
    Validates registration input from Flutter and creates a new User.
    
    Flutter sends: {"username": "...", "email": "...", "password": "..."}
    This serializer:
    1. Checks username isn't already taken
    2. Checks email isn't already taken
    3. Creates the User with a hashed password
    """
    username = serializers.CharField(max_length=150)
    email = serializers.EmailField()
    password = serializers.CharField(write_only=True, min_length=6)
    # write_only=True means password is accepted as input
    # but NEVER included in API responses (security!)

    def validate_username(self, value):
        """Check if username is already taken."""
        if User.objects.filter(username=value).exists():
            raise serializers.ValidationError("Username already taken.")
        return value

    def validate_email(self, value):
        """Check if email is already registered."""
        if User.objects.filter(email=value).exists():
            raise serializers.ValidationError("Email already registered.")
        return value

    def create(self, validated_data):
        """
        Create a new User with a hashed password.
        
        IMPORTANT: We use create_user() instead of User.objects.create()
        because create_user() automatically HASHES the password.
        If we used .create(password="abc"), the password would be stored
        as plain text — a massive security hole!
        """
        user = User.objects.create_user(
            username=validated_data["username"],
            email=validated_data["email"],
            password=validated_data["password"],
        )
        # Profile is auto-created by the signal in models.py
        return user


class LoginSerializer(serializers.Serializer):
    """
    Validates login credentials.
    
    Flutter sends: {"username": "...", "password": "..."}
    This serializer uses Django's authenticate() function which:
    1. Looks up the user by username
    2. Checks if the password hash matches
    3. Returns the User object if valid, None if not
    """
    username = serializers.CharField()
    password = serializers.CharField(write_only=True)

    def validate(self, data):
        """
        authenticate() is Django's built-in function that:
        - Finds the user by username
        - Verifies the password against the stored hash
        - Returns the User object or None
        """
        user = authenticate(
            username=data["username"],
            password=data["password"]
        )
        if user is None:
            raise serializers.ValidationError("Invalid username or password.")
        data["user"] = user
        return data
