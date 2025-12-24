--OBS: Os arrays em Lua iniciam em 1, ao em vez de 0, então se for portar para outra linguagem, lembrar desse detalhe importantíssimo
local timeSpeed = 20 --Somente para simulação
local tempoOperar = 0.2 --Tempo para mover pra frente ou rotacionar, vai de acordo com o hardware
local tempoComputar = 0.05 --Tempo para computar a memória do labirinto e as checagens, vai de acordo com o hardware
timeSpeed = 1/timeSpeed

--VARIÁVEIS DO ROBLOX
local RunS = game:GetService("RunService")
local TweenS = game:GetService("TweenService")
local sensorF = script.Parent.SensorF
local sensorL = script.Parent.SensorL
local sensorR = script.Parent.SensorR
local chassi = sensorF.Parent
local led = chassi.Led

local tempoInicial = tick()		--Somente para simução

--VARIÁVEIS DO PROGRAMA
local x = 1		--Posição Inicial (1-20), Setar Manualmente por enquanto
local chaveInicial = false  --False = Eixo X vai ter no máximo 5 células (soma +-5 no eixo Y); True = Eixo X vai ter no máximo 4 células (soma +-4 no eixo Y)
local somaEixoY = 5
if chaveInicial then
	somaEixoY = 4
end

local mX = 0		--Varíavel para emular a posição do micro em uma matriz (0-4), usado para detectar se o micro irá para uma borda do labirinto
local mY = 0		--Varíavel para emular a posição do micro em uma matriz (0-4)
local rotation = 0		--0 = cima, 1 = direita, 2 = baixo, 3 = esquerda
local moveDistance = 8 		--Distância de movimento, é o a distância entre o "centro" de duas células

local matriz = table.create(20, false) 	--matriz com 20 valores, que representam se a posição já foi visitada

local pilhaSol = {} --Armazenamento da pilha solução do labirinto
local xFinal = 50	--Ele representa uma última posição hipotética, apenas para representar ao micro qual posição ir para resolver o labirinto
local pilhaUltimosPos = {}	--Armazenamento das últimas posições da pilhaSol com bifurcações
local pilha = {}	--Armazenamento da pilha com o caminho atual percorrido
local pilha2 = {}	--Pilha temporária

local distanciaSaida = math.huge --Número de passos até a saída, math.huge no lua significa "infinito"

--==[ Funções de Lógica ]==--

local function checarSensor(sensor)		--Função que retorna o estado do sensor
	local ray = workspace:Raycast(sensor.Position + sensor.CFrame.LookVector*1, sensor.CFrame.LookVector*(moveDistance/2), RaycastParams.new()) --Executar o sensor --FUNÇÃO DO ROBLOX
	if ray then
		return true
	else
		return false
	end
end

local function pegarProximoX(rot)	--Retorna o número do caminho logo a frente, em forma de contagem
	local proximoX = x
	if rot == 0 then	--Mover para cima
		proximoX = x - somaEixoY
	end
	if rot == 1 then	--Mover para a direita
		proximoX = x + 1
	end
	if rot == 2 then --Mover para baixo
		proximoX = x + somaEixoY
	end
	if rot == 3 then --Rot = 3; Mover para esquerda
		proximoX = x - 1
	end
	return proximoX
end

local function checarProximoM(rot, reset)	--Retorna o número do caminho logo a frente, em forma de matriz
	--Se o reset estiver ativado, então a função serve como checagem. Senão, servirá para checagem e para movimentação
	local imX = mX
	local imY = mY
	if rot == 0 then	--Mover para cima
		mY -= 1
	end
	if rot == 1 then	--Mover para a direita
		mX += 1
	end
	if rot == 2 then --Mover para baixo
		mY += 1
	end
	if rot == 3 then --Mover para esquerda
		mX -= 1
	end
	local function resetM()		--Reseta os valores de mX e mY
		if reset then
			mX = imX
			mY = imY
		end
	end
	if chaveInicial == false then		--Eixo X = 5 células
		if mX > 4 or mX < 0 or mY > 3 or mY < 0 then	--Se as coordenadas mX e/ou mY forem de "bordas"
			resetM()
			return true
		end
	else			--Eixo X = 4 células
		if mX > 3 or mX < 0 or mY > 4 or mY < 0 then	--Se as coordenadas mX e/ou mY forem de "bordas"
			resetM()
			return true
		end
	end
	resetM()		--Se não extrapolar o intervalo limite, retorna falso
	return false
end

local function pop(tab)		--Função pop da pilha
	local n = #tab
	table.remove(tab, n)
end

local function push(tab, value)		--Função push da pilha
	local n = #tab
	tab[n+1] = value
end

local function buscarElemento(tab, value)		--Função que checa se um elemento está na pilha
	for i, v in pairs(tab) do
		if v == value then		--Se encontrou o valor, retorna true
			return true
		end
	end
	return false
end

local function resetNotSol()
	for xi = 1, 20 do		--Põe todos os valores diferentes da pilha solução para rechecagem
		if buscarElemento(pilhaSol, xi) == false then
			matriz[xi] = false
		end
	end
end

local function somarRot()	--Retorna o valor da rotação atual do carrinho + 1 (ou seja, 90 graus no horário)
	local rotV = rotation
	if rotV == 3 then
		rotV = 0
	else
		rotV += 1
	end
	return rotV
end

local function subRot()		--Retorna o valor da rotação atual do carrinho - 1 (ou seja, 90 graus no antihorário)
	local rotV = rotation
	if rotV == 0 then
		rotV = 3
	else
		rotV -= 1
	end
	return rotV
end

local function meiaVolta()  --Retorna o valor da rotação atual do carrinho + 2 (ou seja, 180 graus)
	local rotV = rotation
	if rotV == 2 then
		rotV = 0
	elseif rotV == 3 then
		rotV = 1
	else
		rotV += 2
	end
	return rotV
end

--==[ Funções de Movimento ]==--
local function rotateClock()		--Rotaciona o carrinho em 90 graus no horário
	rotation = somarRot()
	
	local Tween = TweenS:Create(chassi, TweenInfo.new(tempoOperar*timeSpeed), {CFrame = chassi.CFrame * CFrame.Angles(0, math.rad(-90), 0)}) 	--FUNÇÃO DO ROBLOX
	Tween:Play()	--Colocar para o motor rotacionar 90 graus no sentido horário

	Tween.Completed:Wait()	--Timer para o Movimento de Rotação finalizar
end
local function rotateAntiClock()	--Rotaciona o carrinho em 90 graus no antihorário
	rotation = subRot()
	
	local Tween = TweenS:Create(chassi, TweenInfo.new(tempoOperar*timeSpeed), {CFrame = chassi.CFrame * CFrame.Angles(0, math.rad(90), 0)})		--FUNÇÃO DO ROBLOX
	Tween:Play()	--Colocar para o motor rotacionar 90 graus no sentido anti-horário

	Tween.Completed:Wait()	--Timer para o Movimento de Rotação finalizar
end

local function moverFrente()		--Move o carrinho para frente
	--Move para frente e atualiza as posições de x e da Matriz
	x = pegarProximoX(rotation)
	checarProximoM(rotation, false)

	local Tween = TweenS:Create(chassi, TweenInfo.new(tempoOperar*timeSpeed), {CFrame = chassi.CFrame + chassi.CFrame.LookVector*moveDistance})
	Tween:Play()	--Colocar para o motor mover uma célula para frente

	Tween.Completed:Wait()	--Timer para o Movimento de Movimentação finalizar
end

local function voltarPos()		--Volta 1 posição na pilha
	local posAnterior = pilha[#pilha]
	if pegarProximoX(meiaVolta()) == posAnterior then		--Caso em que a posição de retorna está ATRÁS do micro
		rotateClock()
		rotateClock()
	end
	if pegarProximoX(subRot()) == posAnterior then		--Caso em que a posição de retorna está na ESQUERDA do micro
		rotateAntiClock()
	end
	if pegarProximoX(somarRot()) == posAnterior then		--Caso em que a posição de retorna está na DIREITA do micro
		rotateClock()
	end
	pop(pilha)
	moverFrente()
end

local function seguirPos(pos)		--Executa o movimento de seguir para uma dada posição vizinha
	if pegarProximoX(meiaVolta()) == pos then		--Achou a próxima posição a ser seguida 
		rotateClock()
		rotateClock()
	elseif pegarProximoX(somarRot()) == pos then
		rotateClock()
	elseif pegarProximoX(subRot()) == pos then
		rotateAntiClock()		
	end
	moverFrente()
end

--==[ ALGORITMO DE MERGE ]==--

local function mergePilhaSol(proximoX)		--Algoritmo que une um trecho da pilha solução + trecho da pilha + trecho da pilha solução, onde o resultado pode ser menor que a pilha solução atual
	--Esse algoritmo usa as intercecções 'proximoX' e o primeiro valor diferente entre as duas pilhas (ultimaPosPSol)
	local function updateSol()
		pilhaSol = table.clone(pilha2)		--Atualiza a pilha solução
		distanciaSaida = #pilha2
		resetNotSol()			--Coloca as outras posições para rechecagem
		table.clear(pilha)
		local proxPos = false
		for index = 1, distanciaSaida do		--Retorna o carrinho para a posição final da pilhaSol e atualiza a pilha
			local xi = pilha2[index]
			if proxPos == true then
				seguirPos(xi)
			end
			if xi == x then
				proxPos = true
			end
			if index == distanciaSaida then
				break
			end
			push(pilha, xi)
		end
		table.clear(pilhaUltimosPos)		--Limpa a pilha de bifurcações
	end
	if buscarElemento(pilhaSol, x) then --Caso em que trecho intermediario = 0; Se o x atual percencer à pilhaSol
		print("TRY MERGE SOL: " .. x .. "  " .. proximoX)
		table.clear(pilhaUltimosPos)
		table.clear(pilha2)
		local open = false		--Variável paramétrica lógica
		for index = 1, distanciaSaida, 1 do
			--Guarda os valores de index = 1 até o primeiro valor que aparecer dentre x ou proximoX
			--Depois guarda os valores a partir do segundo valor que aparecer dentre x ou proximoX até o último elemento da pilha
			local xi = pilhaSol[index]
			if xi == x or xi == proximoX then
				push(pilha2, xi)
				open = not open
			elseif open == false then
				push(pilha2, xi)
			end
		end
		if #pilha2 < distanciaSaida then		--Se a pilha do merge tiver tamanho menor que a pilhaSol, então ela é a nova pilhaSol
			print("Merge Tipo 1")
			updateSol()
			return true
		end
	else	--Caso em que trecho intermediario > 0
		print(pilhaUltimosPos)
		for i = 1, #pilhaUltimosPos do		--Fará merges entre todos os últimos pontos de bifurcações da pilhaSol
			print("TRY MERGE SOL: " .. pilhaUltimosPos[i] .. "  " .. proximoX)
			local ultimaPosPSol = pilhaUltimosPos[i]
			if ultimaPosPSol ~= proximoX and pilhaUltimosPos[1] ~= proximoX then
				table.clear(pilha2)		--Limpa a pilha2
				push(pilha, x)			--Coloca a posição atual do carrinho na pilha, para checagem
				local nextIndex = 1		--Index que será repassado para o loop do próximo trecho
				local ultimoV = pilhaSol[distanciaSaida]		--Ultima posição da pilhaSol
				for index = 1, distanciaSaida do		--Trecho Inicial do merge
					local xi = pilhaSol[index]
					push(pilha2, xi)
					print("T1: " .. xi)
					if (xi == proximoX or xi == ultimaPosPSol) then
						nextIndex = index+1
						break
					end
				end
				for index = nextIndex, distanciaSaida do		--Trecho intermediário do merge
					local xi = pilhaSol[index]
					if pilhaSol[index-1] == ultimaPosPSol or xi == ultimoV then
						nextIndex = index+1
						for i2 = #pilha, 1, -1 do
							push(pilha2, pilha[i2])
							print("TI: " .. pilha[i2])
							if pilha[i2] == ultimaPosPSol then
								break
							end
						end
						if xi ~= ultimoV  then
							print("TI: " .. x)
							push(pilha2, xi)
						end
						break
					end
				end
				for index = nextIndex, distanciaSaida do		--Trecho final do merge
					local xi = pilhaSol[index]
					push(pilha2, xi)
					print("T2: " .. xi)
				end
				if buscarElemento(pilha2, ultimoV) == false then	--Se ao final do merge, a ultima posição da pilhaSol não estiver presente, vai inserir ela no final da pilha2
					push(pilha2, ultimoV)
				end
				pop(pilha, x)		--Retira a posição atual do carrinho na pilha
				if #pilha2 < distanciaSaida then		--Se a pilha do merge tiver tamanho menor que a pilhaSol, então ela é a nova pilhaSol
					print("MERGE PILHA SOL: " .. pilhaUltimosPos[i] .. "  " .. proximoX)
					updateSol()
					break
				else	--Se não, guarda o valor na pilha de bifurcações
					print("falhou no merge: " .. pilhaUltimosPos[i] .. "  " .. proximoX)
					push(pilhaUltimosPos, proximoX)
				end
			end
		end
	end
	return false
end

--==[ Primeiro Loop Principal - Mapeamento ]==--

local procurarSaida = true
local checouTudo = false

local function coroutineViewer()	--FUNÇÃO DO ROBLOX -- Pode apagar
	local pasta = workspace["5x4"]
	if chaveInicial then
		pasta = workspace["4x5"]
	end
	while true do
		RunS.Stepped:Wait()
		game.StarterGui.ScreenGui.Frame.TextLabel.Text = "caminho (pilha): [ " .. table.concat(pilha, ", ") .. " ]"
		game.StarterGui.ScreenGui.Frame.TextLabel2.Text = "solução (pilhaSol): [ " .. table.concat(pilhaSol, ", ") .. " ]"

		for i, v in pairs(matriz) do
			local pad = pasta:FindFirstChild(tostring(i))
			if v == false then
				pad.Color = Color3.new(1, 0 ,0)
			else
				pad.Color = Color3.new(0, 1, 0)
				for i2, xi in pairs(pilhaSol) do
					if (procurarSaida == true and xi == i) or (procurarSaida == false and i2 ~= #pilhaSol and xi == i) then
						pad.Color = Color3.new(0, 0, 1)
					end
				end
			end
		end
	end
end

local corView = coroutine.create(coroutineViewer)
coroutine.resume(corView)

while procurarSaida do		--Loop de buscar a Saída
	RunS.Stepped:Wait()
	wait(tempoComputar*timeSpeed)
	local beco = true		--Variáveis de controle
	local buscarSaida = true
	local checagemAtual = true
	
	while checagemAtual do		--Loop de checagem das células, reinicia após o micro ir para uma nova célula
		matriz[x] = true --Setar a posição atual como já visitada
		local proximoX = 50	--Proxima posição encontrada
		local borda = false		--Borda true ou false
		local recheck = true
		local function tratamento(rotV)
			if buscarSaida then		--Primeiramente, o micro irá buscar se há uma SAÍDA - MODO DE CHECAGEM DE SAÍDA
				if borda == false then	-- MODO DE BUSCAR MERGE NA PILHA
					if matriz[proximoX] == true then
						if buscarElemento(pilhaSol, proximoX) then
							--Se o micro identificou um caminho da pilhaSol, então ele executará o algoritmo de merge
							mergePilhaSol(proximoX)
						end
					end
				elseif xFinal == 50 then	--Detectar se a proxima posição é uma célula de borda, ou seja, uma saída.
					print("ACHOU SAIDA")
					push(pilha, x)		--Push na posição atual da pilha
					xFinal = proximoX
					distanciaSaida = #pilha
					print(pilha)
					pilhaSol = table.clone(pilha)	--Guarda a pilha atual como a pilha solução
					pop(pilha)		--Desfaz o push
					resetNotSol()
					buscarSaida = false
					borda = false
				end
			elseif borda == false then	--Segundamente, ele irá buscar um novo caminho - MODO DE CHECAGEM DE CAMINHO LIVRE
				if matriz[proximoX] == false then		--Se a próxima posição tiver livre o micro irá seguir para ela
					if buscarElemento(pilhaSol, x) then
						push(pilhaUltimosPos, x)
					end
					if rotV == somarRot() then		--Alinha rotação
						rotateClock()
					elseif rotV == subRot() then
						rotateAntiClock()
					end
					push(pilha, x)
					moverFrente()		--Mover para frente
					checagemAtual = false		--Desabilita novas checagens
				end
			end
		end
		local function checarSensores()
			if checarSensor(sensorR) == false then
				local rotV = somarRot()
				proximoX = pegarProximoX(rotV)
				borda = checarProximoM(rotV, true)
				beco = false
				tratamento(rotV)
			end
			if checarSensor(sensorF) == false and checagemAtual then		--Vai checar o sensor só se checagemAtual ainda estiver true
				proximoX = pegarProximoX(rotation)
				borda = checarProximoM(rotation, true)
				beco = false
				tratamento(rotation)
			end
			if checarSensor(sensorL) == false and checagemAtual then		--Vai checar o sensor só se checagemAtual ainda estiver true
				local rotV = subRot()
				proximoX = pegarProximoX(rotV)
				borda = checarProximoM(rotV, true)
				beco = false
				tratamento(rotV)
			end
		end
		buscarSaida = true
		checarSensores()		--Checagem no modo 'Busca da Saída/Merge Pilha'
		buscarSaida = false
		checarSensores()		--Checagem no modo 'Busca de Caminho Livre'
		--A partir daqui, o carrinho não achou nenhum caminho
		if beco == true then
			rotateClock()
		else
			if matriz[x] == true then
				if #pilha == 0 then		--Se o micro estiver na posição de inicio do mapeamento novamente, ele encerra o mapeamento
										--Como a posição inicial xInicial dele é no canto do mapa, ele só pode voltar para xInicial até 2x
					checagemAtual = false
					if checouTudo then
						procurarSaida = false		--Encerra o loop
					end
					checouTudo = true
				else
					if matriz[pegarProximoX(meiaVolta())] == true then		--Se a posição traseira tiver true
						voltarPos()		--Executa algoritmo de voltar 1 posição
					else
						rotateClock()	--Rotaciona para realizar nova checagem
					end
				end
			end
		end
	end
end

print("=Tempo: " .. tostring(tick() - tempoInicial))
led.Material = Enum.Material.Neon --Acender o Led verde, sinalizando o inicio de resolução

push(pilhaSol, xFinal)	--Move o xFinal para o caminho solução

wait(1)		--Timer opcional para o carrinho começar a resolver o labirinto

--==[ Segundo Loop Principal - Saída ]==--

tempoInicial = tick()

for i = 2, distanciaSaida + 1 do	--Leitura da Pilha solução
	seguirPos(pilhaSol[i])
end

print("=TempoF: " .. tostring(tick() - tempoInicial))

while true do  --Dancinha no final xD
	rotateClock()
	rotateClock()
	rotateAntiClock()
	rotateAntiClock()
	rotateClock()
	wait()
end