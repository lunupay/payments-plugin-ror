Rails.application.routes.draw do
	root 'pages#example'

	post 'lunu_pay/create' => 'lunu_pay#create'
	post 'lunu_pay/notify' => 'lunu_pay#notify'
end
