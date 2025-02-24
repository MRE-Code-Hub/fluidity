#include "fdebug.h"

module smoothing_module
  use fldebug
  use global_parameters, only : OPTION_PATH_LEN
  use sparse_tools
  use element_numbering, only: FAMILY_SIMPLEX
  use metric_tools
  use fetools
  use fields
  use state_module
  use sparsity_patterns
  use solvers
  use boundary_conditions, only: apply_dirichlet_conditions
  implicit none

  private

  public :: smooth_scalar, smooth_vector, smooth_tensor
  public :: anisotropic_smooth_scalar, anisotropic_smooth_vector, anisotropic_smooth_tensor
  public :: length_scale_scalar, length_scale_tensor

contains

  subroutine smooth_scalar(field_in,positions,field_out,alpha, path)

    !smoothing length
    real, intent(in) :: alpha
    !input field
    type(scalar_field), intent(inout) :: field_in
    !coordinates field
    type(vector_field), intent(in) :: positions
    !output field, should have same mesh as input field
    type(scalar_field), intent(inout) :: field_out
    character(len=*), intent(in) :: path

    !local variables
    type(csr_matrix) :: M
    type(csr_sparsity) :: M_sparsity
    type(scalar_field) :: RHSFIELD
    integer :: ele

    !allocate smoothing matrix
    M_sparsity=make_sparsity(field_in%mesh, &
         & field_in%mesh, name='HelmholtzScalarSparsity')
    call allocate(M, M_sparsity, name="HelmholtzScalarSmoothingMatrix")
    call deallocate(M_sparsity)
    call zero(M)

    !allocate RHSFIELD
    call allocate(rhsfield, field_in%mesh, "HelmholtzScalarSmoothingRHS")
    call zero(rhsfield)

    ! Assemble M element by element.
    do ele=1, element_count(field_in)
       call assemble_smooth_scalar(M, rhsfield, positions, field_in, alpha, ele)
    end do

    ! Boundary conditions
    ewrite(2,*) "Applying strong Dirichlet boundary conditions to filtered field"
    call apply_dirichlet_conditions(M, rhsfield, field_in)

    call zero(field_out)
    call petsc_solve(field_out, M, rhsfield, option_path=trim(path))

    call deallocate(rhsfield)
    call deallocate(M)

  end subroutine smooth_scalar

  subroutine smooth_vector(field_in,positions,field_out,alpha, path)

    !smoothing length
    real, intent(in) :: alpha
    !input field
    type(vector_field), intent(inout) :: field_in
    !coordinates field
    type(vector_field), intent(in) :: positions
    !output field, should have same mesh as input field
    type(vector_field), intent(inout) :: field_out
    character(len=*), intent(in) :: path

    !local variables
    type(csr_matrix) :: M
    type(csr_sparsity) :: M_sparsity
    type(vector_field) :: RHSFIELD
    integer :: ele, dim

    !allocate smoothing matrix
    M_sparsity=make_sparsity(field_in%mesh, &
         & field_in%mesh, name='HelmholtzVectorSparsity')
    call allocate(M, M_sparsity, name="HelmholtzVectorSmoothingMatrix")
    call deallocate(M_sparsity)
    call zero(M)

    !allocate RHSFIELD
    call allocate(rhsfield, field_in%dim, field_in%mesh, "HelmholtzVectorSmoothingRHS")
    call zero(rhsfield)

    ! Assemble M element by element.
    do ele=1, element_count(field_in)
       call assemble_smooth_vector(M, rhsfield, positions, field_in, alpha, ele)
    end do

    ewrite(2,*) "Applying strong Dirichlet boundary conditions to filtered field"
    do dim=1, field_in%dim
      call apply_dirichlet_conditions(matrix=M, rhs=rhsfield, field=field_in, dim=dim)
    end do

    call zero(field_out)
    call petsc_solve(field_out, M, rhsfield, option_path=trim(path))

    call deallocate(rhsfield)
    call deallocate(M)

  end subroutine smooth_vector

  subroutine smooth_tensor(field_in,positions,field_out,alpha, path)

    !smoothing length
    real, intent(in) :: alpha
    !input field
    type(tensor_field), intent(inout) :: field_in
    !coordinates field
    type(vector_field), intent(in) :: positions
    !output field, should have same mesh as input field
    type(tensor_field), intent(inout) :: field_out
    character(len=*), intent(in) :: path

    !local variables
    type(csr_matrix) :: M
    type(csr_sparsity) :: M_sparsity
    type(tensor_field) :: rhsfield
    integer :: ele

    !allocate smoothing matrix
    M_sparsity=make_sparsity(field_in%mesh, &
         & field_in%mesh, name='HelmholtzTensorSparsity')
    call allocate(M, M_sparsity, name="HelmholtzTensorSmoothingMatrix")
    call deallocate(M_sparsity)
    call zero(M)

    !allocate RHSFIELD
    call allocate(rhsfield, field_in%mesh, "HelmholtzTensorSmoothingRHS")
    call zero(rhsfield)

    ! Assemble M element by element.
    do ele=1, element_count(field_in)
       call assemble_smooth_tensor(M, rhsfield, positions, field_in, alpha, ele)
    end do

    call zero(field_out)
    call petsc_solve(field_out, M, rhsfield, option_path=trim(path))

    call deallocate(rhsfield)
    call deallocate(M)

  end subroutine smooth_tensor

  subroutine anisotropic_smooth_scalar(field_in,positions,field_out,alpha,path)

    !smoothing length
    real, intent(in)                  :: alpha
    !input field
    type(scalar_field), intent(inout) :: field_in
    !coordinates
    type(vector_field), pointer, intent(in) :: positions
    !output field, should have same mesh as input field
    type(scalar_field), intent(inout) :: field_out
    character(len=*), intent(in)      :: path

    !local variables
    type(csr_matrix) :: M
    type(csr_sparsity) :: M_sparsity
    type(scalar_field) :: rhsfield
    integer :: ele

    !allocate smoothing matrix, RHS
    M_sparsity=make_sparsity(field_in%mesh, field_in%mesh, name='HelmholtzScalarSparsity')
    call allocate(M, M_sparsity, name="HelmholtzScalarSmoothingMatrix")
    call allocate(rhsfield, field_in%mesh, "HelmholtzScalarSmoothingRHS")
    call zero(M); call zero(rhsfield); call zero(field_out)

    ! Assemble M element by element.
    do ele=1, element_count(field_in)
       call assemble_anisotropic_smooth_scalar(M, rhsfield, positions, field_in, alpha, ele)
    end do

    ! Boundary conditions
    ewrite(2,*) "Applying strong Dirichlet boundary conditions to filtered field"
    call apply_dirichlet_conditions(M, rhsfield, field_in)

    call petsc_solve(field_out, M, rhsfield, option_path=trim(path))

    call deallocate(rhsfield); call deallocate(M); call deallocate(M_sparsity)

  end subroutine anisotropic_smooth_scalar

  subroutine anisotropic_smooth_vector(field_in,positions,field_out,alpha,path)

    !smoothing length
    real, intent(in) :: alpha
    !input field
    type(vector_field), intent(inout) :: field_in
    !coordinates field
    type(vector_field), intent(in) :: positions
    !output field, should have same mesh as input field
    type(vector_field), intent(inout) :: field_out
    character(len=*), intent(in) :: path

    !local variables
    type(csr_matrix) :: M
    type(csr_sparsity) :: M_sparsity
    type(vector_field) :: rhsfield
    integer :: ele, dim

    !allocate smoothing matrix
    M_sparsity=make_sparsity(field_in%mesh, field_in%mesh, name='HelmholtzVectorSparsity')
    call allocate(M, M_sparsity, name="HelmholtzVectorSmoothingMatrix")
    call allocate(rhsfield, field_in%dim, field_in%mesh, "HelmholtzVectorSmoothingRHS")
    call zero(M); call zero(rhsfield); call zero(field_out)

    ! Assemble M element by element.
    do ele=1, element_count(field_in)
       call assemble_anisotropic_smooth_vector(M, rhsfield, positions, field_in, alpha, ele)
    end do

    ewrite(2,*) "Applying strong Dirichlet boundary conditions to filtered field"
    do dim=1, field_in%dim
      call apply_dirichlet_conditions(matrix=M, rhs=rhsfield, field=field_in, dim=dim)
    end do

    call petsc_solve(field_out, M, rhsfield, option_path=trim(path))

    call deallocate(rhsfield); call deallocate(M); call deallocate(M_sparsity)

  end subroutine anisotropic_smooth_vector

  subroutine anisotropic_smooth_tensor(field_in,positions,field_out,alpha, path)

    !smoothing length
    real, intent(in) :: alpha
    !input field
    type(tensor_field), intent(inout) :: field_in
    !coordinates field
    type(vector_field), intent(in) :: positions
    !output field, should have same mesh as input field
    type(tensor_field), intent(inout) :: field_out
    character(len=*), intent(in) :: path

    !local variables
    type(csr_matrix) :: M
    type(csr_sparsity) :: M_sparsity
    type(tensor_field) :: rhsfield
    integer :: ele

    !allocate smoothing matrix
    M_sparsity=make_sparsity(field_in%mesh, &
         & field_in%mesh, name='HelmholtzTensorSparsity')
    call allocate(M, M_sparsity, name="HelmholtzTensorSmoothingMatrix")
    call deallocate(M_sparsity)
    call zero(M)

    !allocate RHSFIELD
    call allocate(rhsfield, field_in%mesh, "HelmholtzTensorSmoothingRHS")
    call zero(rhsfield)

    ! Assemble M element by element.
    do ele=1, element_count(field_in)
       call assemble_anisotropic_smooth_tensor(M, rhsfield, positions, field_in, alpha, ele)
    end do

    call zero(field_out)
    call petsc_solve(field_out, M, rhsfield, option_path=trim(path))

    call deallocate(rhsfield)
    call deallocate(M)

  end subroutine anisotropic_smooth_tensor

  subroutine assemble_smooth_scalar(M, rhsfield, positions, field_in, alpha, ele)
    type(csr_matrix), intent(inout) :: M
    type(scalar_field), intent(inout) :: RHSFIELD
    type(vector_field), intent(in) :: positions
    type(scalar_field), intent(in) :: field_in
    real, intent(in) :: alpha
    integer, intent(in) :: ele

    ! value of field_in at quad points
    real, dimension(ele_ngi(positions,ele)) :: field_in_quad
    ! smoothing tensor at quadrature points real,
    real,dimension(positions%dim,positions%dim,ele_ngi(positions,ele)) &
         &:: alpha_quad
    ! Derivatives of shape function:
    real, dimension(ele_loc(field_in,ele), &
         ele_ngi(field_in,ele), positions%dim) :: dshape_field_in
    ! Coordinate transform * quadrature weights.
    real, dimension(ele_ngi(positions,ele)) :: detwei
    ! Node numbers of field_in element.
    integer, dimension(:), pointer :: ele_field_in
    ! Shape functions.
    type(element_type), pointer :: shape_field_in
    ! Local Helmholtz matrix
    real, dimension(ele_loc(field_in, ele), ele_loc(field_in, ele)) &
         & :: field_in_mat
    ! Local right hand side.
    real, dimension(ele_loc(field_in, ele)) :: lrhsfield
    real :: w
    integer :: i

    ele_field_in=>ele_nodes(field_in, ele)
    shape_field_in=>ele_shape(field_in, ele)
    field_in_quad = ele_val_at_quad(field_in, ele)

    ! Calculate filter width using Deardorff's definition:
    ! width^2 = (volume)^(2/d)
    w = length_scale_scalar(positions, ele)
    !value of tensor at quads
    forall(i=1:ele_ngi(positions,ele))
        alpha_quad(:,:,i) = alpha**2/24.*w
    end forall

    ! Transform derivatives and weights into physical space.
    call transform_to_physical(positions, ele, shape_field_in, dshape&
         &=dshape_field_in, detwei=detwei)

    ! Local assembly:
    field_in_mat=dshape_tensor_dshape(dshape_field_in, alpha_quad, &
         dshape_field_in, detwei) + shape_shape(shape_field_in&
         &,shape_field_in, detwei)

    lrhsfield=shape_rhs(shape_field_in, field_in_quad*detwei)

    ! Global assembly:
    call addto(M, ele_field_in, ele_field_in, field_in_mat)

    call addto(rhsfield, ele_field_in, lrhsfield)

  end subroutine assemble_smooth_scalar

  subroutine assemble_smooth_vector(M, rhsfield, positions, field_in, alpha, ele)

    type(csr_matrix), intent(inout) :: M
    type(vector_field), intent(inout) :: RHSFIELD
    type(vector_field), intent(in) :: positions
    type(vector_field), intent(in) :: field_in
    real, intent(in) :: alpha
    integer, intent(in) :: ele

    ! value of field_in at quad points
    real, dimension(positions%dim,ele_ngi(positions,ele)) :: field_in_quad
    ! smoothing tensor at quadrature points real,
    real,dimension(positions%dim,positions%dim,ele_ngi(positions,ele)) &
         &:: alpha_quad
    ! Derivatives of shape function:
    real, dimension(ele_loc(field_in,ele), &
         ele_ngi(field_in,ele), positions%dim) :: dshape_field_in
    ! Coordinate transform * quadrature weights.
    real, dimension(ele_ngi(positions,ele)) :: detwei
    ! Node numbers of field_in element.
    integer, dimension(:), pointer :: ele_field_in
    ! Shape functions.
    type(element_type), pointer :: shape_field_in
    ! Local Helmholtz matrix
    real, dimension(ele_loc(field_in, ele), ele_loc(field_in, ele)) &
         & :: field_in_mat
    ! Local right hand side.
    real, dimension(positions%dim, ele_loc(field_in, ele)) :: lrhsfield
    real :: w
    integer :: i

    ele_field_in=>ele_nodes(field_in, ele)
    shape_field_in=>ele_shape(field_in, ele)
    field_in_quad = ele_val_at_quad(field_in, ele)

    ! Calculate filter width using Deardorff's definition:
    ! width^2 = (volume)^(2/d)
    w = length_scale_scalar(positions, ele)
    !value of tensor at quads
    forall(i=1:ele_ngi(positions,ele))
        alpha_quad(:,:,i) = alpha**2/24.*w
    end forall

    ! Transform derivatives and weights into physical space.
    call transform_to_physical(positions, ele, shape_field_in, dshape&
         &=dshape_field_in, detwei=detwei)

    ! Local assembly:
    field_in_mat=dshape_tensor_dshape(dshape_field_in, alpha_quad, &
         dshape_field_in, detwei) + shape_shape(shape_field_in&
         &,shape_field_in, detwei)

    lrhsfield=shape_vector_rhs(shape_field_in, field_in_quad, detwei)

    ! Global assembly:
    call addto(M, ele_field_in, ele_field_in, field_in_mat)

    call addto(rhsfield, ele_field_in, lrhsfield)

  end subroutine assemble_smooth_vector

  subroutine assemble_smooth_tensor(M, rhsfield, positions, field_in, alpha, ele)

    type(csr_matrix), intent(inout) :: M
    type(tensor_field), intent(inout) :: RHSFIELD
    type(vector_field), intent(in) :: positions
    type(tensor_field), intent(in) :: field_in
    real, intent(in) :: alpha
    integer, intent(in) :: ele

    ! value of field_in at quad points
    real, dimension(positions%dim,positions%dim,ele_ngi(positions,ele)) :: field_in_quad
    ! smoothing tensor at quadrature points real,
    real,dimension(positions%dim,positions%dim,ele_ngi(positions,ele)) &
         &:: alpha_quad
    ! Derivatives of shape function:
    real, dimension(ele_loc(field_in,ele), &
         ele_ngi(field_in,ele), positions%dim) :: dshape_field_in
    ! Coordinate transform * quadrature weights.
    real, dimension(ele_ngi(positions,ele)) :: detwei
    ! Node numbers of field_in element.
    integer, dimension(:), pointer :: ele_field_in
    ! Shape functions.
    type(element_type), pointer :: shape_field_in
    ! Local Helmholtz matrix
    real, dimension(ele_loc(field_in, ele), ele_loc(field_in, ele)) &
         & :: field_in_mat
    ! Local right hand side.
    real, dimension(positions%dim,positions%dim,ele_loc(field_in, ele)) :: lrhsfield
    real :: w
    integer :: i

    ele_field_in=>ele_nodes(field_in, ele)
    shape_field_in=>ele_shape(field_in, ele)
    field_in_quad = ele_val_at_quad(field_in, ele)

    ! Calculate filter width using Deardorff's definition:
    ! width^2 = (volume)^(2/d)
    w = length_scale_scalar(positions, ele)
    !value of tensor at quads
    forall(i=1:ele_ngi(positions,ele))
        alpha_quad(:,:,i) = alpha**2/24.*w
    end forall

    ! Transform derivatives and weights into physical space.
    call transform_to_physical(positions, ele, shape_field_in, dshape&
         &=dshape_field_in, detwei=detwei)

    ! Local assembly:
    field_in_mat=dshape_tensor_dshape(dshape_field_in, alpha_quad, &
         dshape_field_in, detwei) + shape_shape(shape_field_in&
         &,shape_field_in, detwei)

    lrhsfield=shape_tensor_rhs(shape_field_in, field_in_quad, detwei)

    ! Global assembly:
    call addto(M, ele_field_in, ele_field_in, field_in_mat)

    call addto(rhsfield, ele_field_in, lrhsfield)

  end subroutine assemble_smooth_tensor

  subroutine assemble_anisotropic_smooth_scalar(M, rhsfield, positions, field_in, alpha, ele)
    type(csr_matrix), intent(inout) :: M
    type(scalar_field), intent(inout) :: rhsfield
    type(vector_field), intent(in) :: positions
    type(scalar_field), intent(in) :: field_in
    real, intent(in) :: alpha
    integer, intent(in) :: ele
    real, dimension(ele_ngi(positions,ele))                                      :: field_in_quad
    real,dimension(positions%dim,positions%dim,ele_ngi(positions,ele))           :: mesh_tensor_quad
    real, dimension(ele_loc(field_in,ele), ele_ngi(field_in,ele), positions%dim) :: dshape_field_in
    real, dimension(ele_ngi(positions,ele))                                      :: detwei
    integer, dimension(:), pointer                                               :: ele_field_in
    type(element_type), pointer                                                  :: shape_field_in
    real, dimension(ele_loc(field_in, ele), ele_loc(field_in, ele))              :: field_in_mat
    real, dimension(ele_loc(field_in, ele))                                      :: lrhsfield

    ele_field_in=>ele_nodes(field_in, ele)
    shape_field_in=>ele_shape(field_in, ele)
    field_in_quad = ele_val_at_quad(field_in, ele)

    ! Transform derivatives and weights into physical space.
    call transform_to_physical(positions, ele, shape_field_in, dshape&
         &=dshape_field_in, detwei=detwei)

    ! mesh size tensor=(edge lengths)**2
    ! Helmholtz smoothing lengthscale = alpha**2 * 1/24 * mesh size tensor
    ! factor 1/24 derives from 2nd moment of filter (see Pope 2000, Geurts&Holm 2002)
    mesh_tensor_quad = alpha**2 / 24. * length_scale_tensor(dshape_field_in, shape_field_in)

    !ewrite(2,*) 'dsd: ', dshape_tensor_dshape(dshape_field_in, mesh_tensor_quad, dshape_field_in, detwei)
    !ewrite(2,*) 'srhs: ', shape_shape(shape_field_in,shape_field_in, detwei)
    ! Local assembly
    field_in_mat=dshape_tensor_dshape(dshape_field_in, mesh_tensor_quad, dshape_field_in, detwei) &
         & + shape_shape(shape_field_in,shape_field_in, detwei)
    lrhsfield=shape_rhs(shape_field_in, field_in_quad*detwei)

    ! Global assembly
    call addto(M, ele_field_in, ele_field_in, field_in_mat)

    call addto(rhsfield, ele_field_in, lrhsfield)

  end subroutine assemble_anisotropic_smooth_scalar

  subroutine assemble_anisotropic_smooth_vector(M, rhsfield, positions, field_in, alpha, ele)
    type(csr_matrix), intent(inout) :: M
    type(vector_field), intent(inout) :: rhsfield
    type(vector_field), intent(in) :: positions
    type(vector_field), intent(in) :: field_in
    real, intent(in) :: alpha
    integer, intent(in) :: ele
    real, dimension(positions%dim,ele_ngi(positions,ele))                        :: field_in_quad
    real,dimension(positions%dim,positions%dim,ele_ngi(positions,ele))           :: mesh_tensor_quad
    real, dimension(ele_loc(field_in,ele), ele_ngi(field_in,ele), positions%dim) :: dshape_field_in
    real, dimension(ele_ngi(positions,ele))                                      :: detwei
    integer, dimension(:), pointer                                               :: ele_field_in
    type(element_type), pointer                                                  :: shape_field_in
    real, dimension(ele_loc(field_in, ele), ele_loc(field_in, ele))              :: field_in_mat
    real, dimension(positions%dim, ele_loc(field_in, ele))                       :: lrhsfield

    ele_field_in=>ele_nodes(field_in, ele)
    shape_field_in=>ele_shape(field_in, ele)
    field_in_quad = ele_val_at_quad(field_in, ele)

    ! Transform derivatives and weights into physical space.
    call transform_to_physical(positions, ele, shape_field_in, dshape&
         &=dshape_field_in, detwei=detwei)

    ! mesh size tensor=(edge lengths)**2
    ! Helmholtz smoothing lengthscale = alpha**2 * 1/24 * mesh size tensor
    mesh_tensor_quad = alpha**2 / 24. * length_scale_tensor(dshape_field_in, shape_field_in)

    ! Local assembly:
    field_in_mat=dshape_tensor_dshape(dshape_field_in, mesh_tensor_quad, dshape_field_in, detwei) &
         & + shape_shape(shape_field_in, shape_field_in, detwei)
    lrhsfield=shape_vector_rhs(shape_field_in, field_in_quad, detwei)

    ! Global assembly:
    call addto(M, ele_field_in, ele_field_in, field_in_mat)
    call addto(rhsfield, ele_field_in, lrhsfield)

  end subroutine assemble_anisotropic_smooth_vector

  subroutine assemble_anisotropic_smooth_tensor(M, rhsfield, positions, field_in, alpha, ele)
    type(csr_matrix), intent(inout) :: M
    type(tensor_field), intent(inout) :: rhsfield
    type(vector_field), intent(in) :: positions
    type(tensor_field), intent(in) :: field_in
    real, intent(in) :: alpha
    integer, intent(in) :: ele
    real, dimension(positions%dim,positions%dim,ele_ngi(positions,ele))          :: field_in_quad
    real,dimension(positions%dim,positions%dim,ele_ngi(positions,ele))           :: mesh_tensor_quad
    real, dimension(ele_loc(field_in,ele), ele_ngi(field_in,ele), positions%dim) :: dshape_field_in
    real, dimension(ele_ngi(positions,ele))                                      :: detwei
    integer, dimension(:), pointer                                               :: ele_field_in
    type(element_type), pointer                                                  :: shape_field_in
    real, dimension(ele_loc(field_in, ele), ele_loc(field_in, ele))              :: field_in_mat
    real, dimension(positions%dim, positions%dim, ele_loc(field_in, ele))        :: lrhsfield

    ele_field_in=>ele_nodes(field_in, ele)
    shape_field_in=>ele_shape(field_in, ele)
    field_in_quad = ele_val_at_quad(field_in, ele)

    ! Transform derivatives and weights into physical space.
    call transform_to_physical(positions, ele, shape_field_in, dshape&
         &=dshape_field_in, detwei=detwei)

    ! mesh size tensor=(edge lengths)**2
    ! Helmholtz smoothing lengthscale = alpha**2 * 1/24 * mesh size tensor
    mesh_tensor_quad = alpha**2 / 24. * length_scale_tensor(dshape_field_in, shape_field_in)

    ! Local assembly:
    field_in_mat=dshape_tensor_dshape(dshape_field_in, mesh_tensor_quad, dshape_field_in, detwei)&
         & + shape_shape(shape_field_in, shape_field_in, detwei)
    lrhsfield=shape_tensor_rhs(shape_field_in, field_in_quad, detwei)

    ! Global assembly:
    call addto(M, ele_field_in, ele_field_in, field_in_mat)

    call addto(rhsfield, ele_field_in, lrhsfield)

  end subroutine assemble_anisotropic_smooth_tensor

  function length_scale_scalar(positions, ele) result(s)
    ! Computes a scalar length scale for LES models
    ! Preserves element volume. (units are in length^2)
    type(vector_field), intent(in) :: positions
    real :: s
    integer, intent(in) :: ele
    integer :: dim
    dim=positions%dim

    ! filter is a square/cube (width=side length) a la Deardorff:
    s=element_volume(positions, ele)
    s=s**(2./dim)

  end function length_scale_scalar

  function length_scale_tensor(du_t, shape) result(t)
    !! Computes a length scale tensor to be used in LES (units are in length^2)
    !! derivative of velocity shape function (nloc x ngi x dim)
    real, dimension(:,:,:), intent(in):: du_t
    !! the resulting tensor (dim x dim x ngi)
    real, dimension(size(du_t,3),size(du_t,3),size(du_t,2)) :: t
    !! for a simplex if degree==1 the tensor is the same for all gaussian points
    type(element_type), intent(in):: shape

    real, dimension(size(t,1), size(t,2)):: M
    real r
    integer gi, loc, i, dim, nloc, compute_ngi

    t=0.0
    nloc=size(du_t,1)
    dim=size(du_t,3)

    if (.not.(shape%degree==1 .and. shape%numbering%family==FAMILY_SIMPLEX)) then
      ! for non-linear compute on all gauss points
      compute_ngi=shape%ngi
    else
      ! for linear: compute only the first and copy the rest
      compute_ngi=1
    end if

    do gi=1, compute_ngi
       do loc=1, nloc
          ! eigenvalues of metric
          M=outer_product( du_t(loc,gi,:), du_t(loc,gi,:) )
          ! determinant of M
          r=sum( (/ ( M(i,i), i=1, dim) /) )
          ! M^-1 = 1/det(M)*adj(M) = 1/det(M)*M
          if (.not. r==0.0) then
             t(:,:,gi)=t(:,:,gi)+M/(r**2)
          end if
       end do
    end do

    ! copy the rest
    do gi=compute_ngi+1, shape%ngi
       t(:,:,gi)=t(:,:,1)
    end do

  end function length_scale_tensor

end module smoothing_module
