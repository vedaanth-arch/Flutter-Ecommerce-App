from django.urls import path
from . import views

urlpatterns = [
    path('', views.get_products, name='get_products'),
    path('categories/', views.get_categories, name='get_categories'),
    path('subcategories/', views.get_subcategories, name='get_subcategories'),
]