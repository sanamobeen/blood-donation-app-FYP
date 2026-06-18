"""
API Views for Blood Types.

Provides endpoints for listing blood types and their compatibility.
"""
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny
from rest_framework.response import Response

from .models import BloodType
from .serializers import BloodTypeSerializer


def success_response(message, data=None, status_code=status.HTTP_200_OK):
    """Create a standardized success response."""
    response_data = {'success': True, 'message': message}
    if data:
        response_data.update(data)
    return Response(response_data, status=status_code)


def error_response(message, errors=None, status_code=status.HTTP_400_BAD_REQUEST):
    """Create a standardized error response."""
    response_data = {'success': False, 'message': message}
    if errors:
        response_data['errors'] = errors
    return Response(response_data, status=status_code)


@api_view(['GET'])
@permission_classes([AllowAny])
def blood_type_list(request):
    """
    Get list of all active blood types.

    GET /api/blood-types/

    Response (200 OK):
    {
        "success": true,
        "message": "Blood types retrieved",
        "data": {
            "blood_types": [...]
        }
    }
    """
    try:
        blood_types = BloodType.objects.filter(is_active=True).order_by('sort_order', 'code')
        serializer = BloodTypeSerializer(blood_types, many=True)

        return success_response(
            message='Blood types retrieved successfully.',
            data={
                'blood_types': serializer.data,
                'count': blood_types.count()
            }
        )

    except Exception as e:
        return error_response(
            message='Failed to retrieve blood types.',
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['GET'])
@permission_classes([AllowAny])
def blood_type_detail(request, type_id):
    """
    Get details of a specific blood type.

    GET /api/blood-types/{id}/

    Response (200 OK):
    {
        "success": true,
        "message": "Blood type retrieved",
        "data": {
            "blood_type": {...}
        }
    }
    """
    try:
        blood_type = BloodType.objects.get(id=type_id, is_active=True)
        serializer = BloodTypeSerializer(blood_type)

        return success_response(
            message='Blood type retrieved successfully.',
            data={
                'blood_type': serializer.data
            }
        )

    except BloodType.DoesNotExist:
        return error_response(
            message='Blood type not found.',
            status_code=status.HTTP_404_NOT_FOUND
        )

    except Exception as e:
        return error_response(
            message='Failed to retrieve blood type.',
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
        )
