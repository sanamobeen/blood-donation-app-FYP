"""
Serializers for Blood Types app.
"""
from rest_framework import serializers
from .models import BloodType


class BloodTypeSerializer(serializers.ModelSerializer):
    """
    Serializer for BloodType model.
    """

    class Meta:
        model = BloodType
        fields = [
            'id',
            'code',
            'name',
            'compatibility',
            'sort_order',
            'is_active',
        ]
        read_only_fields = ['id']
