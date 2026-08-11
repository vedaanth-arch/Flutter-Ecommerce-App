from rest_framework import serializers
from .models import Product, Category, subCategory


class ProductSerializer(serializers.ModelSerializer):
    class Meta:
        model = Product
        fields = '__all__'


class CategorySerializer(serializers.ModelSerializer):
    class Meta:
        model = Category
        fields = ['id', 'name']


class subCategorySerializer(serializers.ModelSerializer):
    category_name=serializers.CharField(
        source='category.name',read_only=True
    )
    class Meta:
        model = subCategory
        fields = ['id', 'name', 'category','category_name']