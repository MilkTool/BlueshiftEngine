// Copyright(c) 2017 POLYGONTEK
// 
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// 
// http ://www.apache.org/licenses/LICENSE-2.0
// 
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#pragma once

/*
-------------------------------------------------------------------------------

    Various rendering utility functions

-------------------------------------------------------------------------------
*/

BE_NAMESPACE_BEGIN

struct AxisIndex {
    enum Enum {
        Forward,
        Left,
        Up
    };
};

// Converts environment cubemap face to OpenGL axis for rendering.
void    R_EnvCubeMapFaceToOpenGLAxis(RHI::CubeMapFace::Enum face, Mat3 &axis);

// Converts environment cubemap face to engine axis for rendering.
void    R_EnvCubeMapFaceToEngineAxis(RHI::CubeMapFace::Enum face, Mat3 &axis);

// Sets view matrix with the given origin and axis.
void    R_SetViewMatrix(const Mat3 &viewaxis, const Vec3 &vieworg, float *viewMatrix);

// Sets perspective projection matrix.
void    R_SetPerspectiveProjectionMatrix(float xFov, float yFov, float zNear, float zFar, bool infinite, float *projectionMatrix);

// Sets orthogonal projection matrix.
void    R_SetOrthogonalProjectionMatrix(float xSize, float ySize, float zNear, float zFar, float *projectionMatrix);

// Sets 2d crop matrix.
void    R_Set2DCropMatrix(float xmin, float xmax, float ymin, float ymax, float *cropMatrix);

// 삼각형으로 tangent, bitangent 벡터와 손잡이 (handedness) 값 생성.
void    R_TangentsFromTriangle(const Vec3 &v0, const Vec3 &v1, const Vec3 &v2, const Vec2 &st0, const Vec2 &st1, const Vec2 &st2, Vec3 &tangent, Vec3 &binormal, float *handedness);

//
bool    R_CullShadowVolumeBackCap(const Mat4 &viewProjMatrix, const OBB &boundingBox, const Vec3 &lightProjectionOrigin);

// Calculates CSM split distance (GPU Gems3 참고)
void    R_ComputeSplitDistances(float dNear, float dFar, float lamda, int numSplits, float *splitDistances);

// Sets 1D gaussian weights.
void    R_ComputeGaussianWeights(int kernelSize, float *weights);

// 1D linear sampling weight, offset 생성.
void    R_Compute1DLinearSamplingWeightsAndOffsets(int numSamples, const float *weights, float *lweights, Vec2 *hoffsets, Vec2 *voffsets);

// sphere 의 triangle strip verts 를 생성한다.
void    R_GenerateSphereTriangleStripVerts(const Sphere &sphere, int lats, int longs, Vec3 *verts);

//-------------------------------------------------------------------------------
// Linear sampling kernel
//-------------------------------------------------------------------------------
template <int N>
struct LinearKernel {
    float   discreteWeights[N]; // input discrete weights
    float   linearWeights[(N + 1) >> 1];
    Vec2    hOffsets[(N + 1) >> 1];
    Vec2    vOffsets[(N + 1) >> 1];

    void    Compute() { R_Compute1DLinearSamplingWeightsAndOffsets(N, discreteWeights, linearWeights, hOffsets, vOffsets); }
};

BE_NAMESPACE_END
