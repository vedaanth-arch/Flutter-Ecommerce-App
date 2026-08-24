from django.contrib import admin
from django.contrib.auth.models import User

# We use Django's built-in User model (username, email, password).
# We add a Profile model for extra fields (phone, address).
from .models import Profile

# Inline profile editing inside the User admin page
class ProfileInline(admin.StackedInline):
    model = Profile
    can_delete = False
    verbose_name_plural = "Profile"

# Extend the default User admin to show Profile inline
class UserAdmin(admin.ModelAdmin):
    inlines = [ProfileInline]

# Re-register User with our custom admin
admin.site.unregister(User)
admin.site.register(User, UserAdmin)
admin.site.register(Profile)
