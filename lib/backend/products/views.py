from rest_framework.decorators import api_view
from rest_framework.response import Response
from .models import Product,Category,subCategory
from .serializers import ProductSerializer,CategorySerializer,subCategorySerializer 


@api_view(['GET', 'POST'])
def get_products(request):

    if request.method == 'GET':
        category_id=request.query_params.get("category")
        if category_id:
            products=Product.objects.filter(category_id=category_id)
        else:
            products = Product.objects.all()
        serializer = ProductSerializer(products, many=True)
        return Response(serializer.data)

    if request.method == 'POST':
        serializer = ProductSerializer(data=request.data)

        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data)

        return Response(serializer.errors)
    
@api_view(['GET', 'POST'])
def get_categories(request):

    if request.method == 'GET':
        categories = Category.objects.all()
        serializer = CategorySerializer(categories, many=True)
        return Response(serializer.data)

    if request.method == 'POST':
        serializer = CategorySerializer(data=request.data)

        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data)

        return Response(serializer.errors)
@api_view(['GET', 'POST'])
def get_subcategories(request):

    if request.method == 'GET':
        subcategories = subCategory.objects.all()
        serializer = subCategorySerializer(subcategories, many=True)
        return Response(serializer.data)

    if request.method == 'POST':
        serializer = subCategorySerializer(data=request.data)

        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data)

        return Response(serializer.errors)