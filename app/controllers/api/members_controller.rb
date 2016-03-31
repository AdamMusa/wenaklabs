class API::MembersController < API::ApiController
  before_action :authenticate_user!, except: [:last_subscribed]
  before_action :set_member, only: [:update, :destroy, :merge]
  respond_to :json

  def index
    @requested_attributes = params[:requested_attributes]
    @members = policy_scope(User)
  end

  def last_subscribed
    @members = User.active.with_role(:member).includes(:profile).where('is_allow_contact = true AND confirmed_at IS NOT NULL').order('created_at desc').limit(params[:last])
    @requested_attributes = ['profile']
    render :index
  end

  def show
    @member = User.friendly.find(params[:id])
    authorize @member
  end

  def create
    authorize User
    if !user_params[:password] and !user_params[:password_confirmation]
      generated_password = Devise.friendly_token.first(8)
      @member = User.new(user_params.merge(password: generated_password).permit!)
    else
      @member = User.new(user_params.permit!)
    end


    # if the user is created by an admin and the authentication is made through an SSO, generate a migration token
    if current_user.is_admin? and AuthProvider.active.providable_type != DatabaseProvider.name
      @member.generate_auth_migration_token
    end

    if @member.save
      @member.generate_admin_invoice
      @member.send_confirmation_instructions
      if !user_params[:password] and !user_params[:password_confirmation]
        UsersMailer.delay.notify_user_account_created(@member, generated_password)
      else
        UsersMailer.delay.notify_user_account_created(@member, user_params[:password])
      end
      render :show, status: :created, location: member_path(@member)
    else
      render json: @member.errors, status: :unprocessable_entity
    end
  end

  def update
    authorize @member
    @flow_worker = MembersFlowWorker.new(@member)

    if user_params[:group_id] and @member.group_id != user_params[:group_id].to_i and @member.subscribed_plan != nil
      # here a group change is requested but unprocessable, handle the exception
      @member.errors[:group_id] = t('members.unable_to_change_the_group_while_a_subscription_is_running')
      render json: @member.errors, status: :unprocessable_entity
    else
      # otherwise, run the user update
      if @flow_worker.update(user_params)
        # Update password without logging out
        sign_in(@member, :bypass => true) unless current_user.id != params[:id].to_i
        render :show, status: :ok, location: member_path(@member)
      else
        render json: @member.errors, status: :unprocessable_entity
      end
    end
  end

  def destroy
    authorize @member
    @member.soft_destroy
    sign_out(@member)
    head :no_content
  end

  # export subscriptions
  def export_subscriptions
    authorize :export
    @datas = Subscription.includes(:plan, :user).all
    respond_to do |format|
      format.html
      format.xls
    end
  end

  # export reservations
  def export_reservations
    authorize :export
    @datas = Reservation.includes(:user, :slots).all
    respond_to do |format|
      format.html
      format.xls
    end
  end

  def export_members
    authorize :export
    @datas = User.with_role(:member).includes(:group, :subscriptions, :profile)
    respond_to do |format|
      format.html
      format.xls
    end
  end

  def merge
    authorize @member

    # here the user query to be mapped to his already existing account

    token = params.require(:user).permit(:auth_token)[:auth_token]

    @account = User.find_by_auth_token(token)
    if @account
      @flow_worker = MembersFlowWorker.new(@account)
      begin
        if @flow_worker.merge_from_sso(@member)
          @member = @account
          # finally, log on the real account
          sign_in(@member, :bypass => true)
          render :show, status: :ok, location: member_path(@member)
        else
          render json: @member.errors, status: :unprocessable_entity
        end
      rescue DuplicateIndexError => error
        render json: {error: t('members.please_input_the_authentication_code_sent_to_the_address', EMAIL: error.message)}, status: :unprocessable_entity
      end
    else
      render json: {error: t('members.your_authentication_code_is_not_valid')}, status: :unprocessable_entity
    end
  end

  private
    def set_member
      @member = User.find(params[:id])
    end

    def user_params
      if current_user.id == params[:id].to_i
        params.require(:user).permit(:username, :email, :password, :password_confirmation, :group_id, :is_allow_contact,
                                      profile_attributes: [:id, :first_name, :last_name, :gender, :birthday, :phone, :interest, :software_mastered,
                                     :user_avatar_attributes => [:id, :attachment, :_destroy], :address_attributes => [:id, :address]])

      elsif current_user.is_admin?
        params.require(:user).permit(:username, :email, :password, :password_confirmation, :invoicing_disabled,
                                      :group_id, training_ids: [], tag_ids: [],
                                      profile_attributes: [:id, :first_name, :last_name, :gender, :birthday, :phone, :interest, :software_mastered,
                                      user_avatar_attributes: [:id, :attachment, :_destroy], address_attributes: [:id, :address]])

      end
    end
end
