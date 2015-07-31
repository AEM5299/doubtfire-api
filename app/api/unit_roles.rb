require 'grape'

module Api
  class UnitRoles < Grape::API
    helpers AuthHelpers
    helpers AuthorisationHelpers

    before do
      authenticated?
    end

    desc "Get unit roles for authenticated user"
    params do
      optional :unit_id, type: Integer, desc: 'Get user roles in indicated unit'
      optional :include_in_active, type: Boolean, desc: 'Include units that are not active'
    end
    get '/unit_roles' do
      if not authorise? current_user, User, :act_tutor
        return []
      end

      unit_roles = UnitRole.for_user current_user

      if params[:unit_id]
        unit_roles = unit_roles.where(unit_id: params[:unit_id])
      elsif not params[:include_in_active]
        unit_roles = unit_roles.where("units.active = true")
      end

      unit_roles
    end

    desc "Delete a unit role"
    delete '/unit_roles/:id' do 
      unit_role = UnitRole.find(params[:id])

      if not ((authorise? current_user, unit_role.unit, :employ_staff) || (authorise? current_user, User, :admin_units))
        error!({"error" => "Couldn't find UnitRole with id=#{params[:id]}" }, 403)
      end
      
      unit_role.destroy
    end


    desc "Get a unit_role's details"
    get '/unit_roles/:id' do
      unit_role = UnitRole.find(params[:id])

      if not authorise? current_user, unit_role, :get
        error!({"error" => "Couldn't find UnitRole with id=#{params[:id]}" }, 403)
      end
      
      unit_role
    end

    desc "Employ a user as a teaching role in a unit" 
    params do 
      requires :unit_id, type: Integer, desc: 'The id of the unit to employ the staff for'
      requires :user_id, type: Integer, desc: 'The id of the tutor'
      requires :role, type: String, desc: 'The role for the staff member'
    end 
    post '/unit_roles' do 
      unit = Unit.find(params[:unit_id])

      if not ((authorise? current_user, unit, :employ_staff) || (authorise? current_user, User, :admin_units))
        error!({"error" => "Couldn't find Unit with id=#{params[:id]}" }, 403)
      end
      user = User.find(params[:user_id])
      role = Role.with_name(params[:role])

      if role.nil?
        error!({"error" => "Couldn't find Role with name=#{params[:role]}" }, 403)
      end

      if role == Role.student
        error!({"error" => "Enrol students as projects not unit roles" }, 403)
      end

      unit.employ_staff(user, role)
    end 

    desc "Update a role " 
    params do 
      group :unit_role do 
        requires :role_id, type: Integer, desc: 'The role to create with'
      end 
    end 
    put '/unit_roles/:id' do 
      unit_role = UnitRole.find_by_id(params[:id])

      if not ((authorise? current_user, unit_role.unit, :employ_staff) || (authorise? current_user, User, :admin_units))
        error!({"error" => "Couldn't find Unit with id=#{params[:id]}" }, 403)
      end

      unit_role_parameters = ActionController::Parameters.new(params)
        .require(:unit_role)
        .permit(
          :role_id
        )
      
      if unit_role_parameters[:role_id] == Role.tutor.id && unit_role.role == Role.convenor && unit_role.unit.convenors.count == 1
        error!({"error" => "There must be at least one convenor for the unit"}, 403)
      end

      unit_role.update!(unit_role_parameters)
      unit_role
    end 
  end
end
