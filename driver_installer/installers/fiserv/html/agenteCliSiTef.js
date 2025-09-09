agent_url='https://127.0.0.1/agente/clisitef';
var sessao={};

function showStatus(msg) {
	document.getElementById("tef_setup").style.display="none";
	document.getElementById("tef_transacao").style.display="block";
	document.getElementById("tef_titulo").innerHTML = msg;
	document.getElementById("tef_corpo").innerHTML = "";
}

function showMessage(msg) {
	document.getElementById("tef_corpo").innerHTML = msg + "<br/><br/><table width=\"120\"><tr><td><input type=\"BUTTON\" class=\"btn1\" value=\"OK\" onclick=\"resetView();\"/></td></tr></table>";
	document.getElementById("tef_corpo").style.display="block";
	document.getElementById("tef_setup").style.display="none";
	document.getElementById("tef_transacao").style.display="block";
}

function resetView() {
	document.getElementById("tef_setup").style.display="block";
	document.getElementById("tef_transacao").style.display="none";
	if (!sessao.usandoSessao) {
		// Foi usada uma sessao temporária, faz a limpeza pois o servidor removeu a sessão
		sessao.sessionId = 0;
	}
}

// ===========================================================================
// Consulta sobre o estado do Agente CliSiTef

function obtemEstado() {
	showStatus("Conectando Agente...");

	$.ajax({
        	url: agent_url+"/state",
		type:"get",
		data: {},
	})
	.done(function(data) {
		showStatus("Estado do Agente");
		if (data.serviceStatus == 0) {
		
			var s = "Vers&atilde;o do agente: ["+data.serviceVersion+"]<br/><br/>"+data.serviceState;
		
			if (data.serviceState == 0)
				s = s + " - n&atilde;o inicializado.";
			else if (data.serviceState == 1)
				s = s + " - agente pronto para receber solicita&ccedil;&otilde;es.";
			else if (data.serviceState == 2)
				s = s + " - IniciaFuncaoSiTefInterativo iniciado com sucesso - aguardando continua.";
			else if (data.serviceState == 3)
				s = s + " - processo iterativo da clisitef em andamento - aguardando continua.";
			else if (data.serviceState == 4)
				s = s + " - aguardando finaliza.";
			
			if (data.sessionId)
				s = s + "<br/><br/>Sess&atilde;o atual ["+data.sessionId+"]";
			
			showMessage(s);
		}
		else {
			showMessage(data.serviceStatus + " - " + data.serviceMessage);
		}
	})
	.fail(function(xhr, ajaxOptions, thrownError) {
		showMessage( "Erro: " + xhr.status + " - " + thrownError + "<br>" + xhr.responseText);
	});
}

// ===========================================================================
// Funcoes para gerenciamento de Sessao: Criar/Finalizar, consultar sessão atual

function criaSessaoId() {
	var ret = [];
	sessao.ret = ret;
	sessao.continua = 0;
	sessao.cupomFiscal = "";
	sessao.dataFiscal = "";
	sessao.horaFiscal = "";

	showStatus("Criando sessão...");

	$.ajax({
		url: agent_url+"/session",
		type:"post",
		data:{
			"sitefIp":document.getElementById("SITEF").value,
			"storeId":document.getElementById("EMPRESA").value,
			"terminalId":document.getElementById("TERMINAL").value,
			"sessionParameters":document.getElementById("SESSAO_PARAMS").value,
		},
	})
	.done(function(data) {
		if (data.serviceStatus == 0) {
			// Salva a sessionId e dados da conexao
			sessao.sessionId=data.sessionId;
			sessao.usandoSessao = 1;
			sessao.empresa=document.getElementById("EMPRESA").value;
			sessao.terminal=document.getElementById("TERMINAL").value;
			sessao.siTefIP=document.getElementById("SITEF").value;
			
			showMessage("Sess&atilde;o criada [" + data.sessionId + "]");
		}
		else {
			showMessage(data.serviceStatus + " - " + data.serviceMessage);
		}
	})
	.fail(function(xhr, ajaxOptions, thrownError) {
		showMessage( "Erro: " + xhr.status + " - " + thrownError + "<br>" + xhr.responseText);
	});
}

function destroiSessaoId() {
	var ret = [];
	sessao.ret = ret;
	sessao.continua = 0;
	sessao.cupomFiscal = "";
	sessao.dataFiscal = "";
	sessao.horaFiscal = "";

	showStatus("Finalizando sessão...");

	$.ajax({
		url: agent_url+"/session",
		type:"delete",
		//data:{
		//	"sessionId":sessao.sessionId,
		//},
	})
	.done(function(data) {
		if (data.serviceStatus == 0) {
			showMessage("Sessao finalizada");
		}
		else {
			showMessage(data.serviceStatus + " - " + data.serviceMessage);
		}
	})
	.fail(function(xhr, ajaxOptions, thrownError) {
		showMessage( "Erro: " + xhr.status + " - " + thrownError + "<br>" + xhr.responseText);
	});
	
	// Limpa a sessionId, independente de ter dado erro.
	sessao.sessionId = "";
	sessao.usandoSessao = 0;
}

function obtemSessaoId() {
	showStatus("Obtendo sessão...");

	$.ajax({
        	url: agent_url+"/session",
		type:"get",
		data: {},
	})
	.done(function(data) {
		if (data.serviceStatus == 0) {
			// Salva a sessionId
			sessao.sessionId=data.sessionId;
			sessao.usandoSessao = 1;
			showMessage("Sessao atual [" + data.sessionId + "]");
		}
		else {
			showMessage(data.serviceStatus + " - " + data.serviceMessage);
		}
	})
	.fail(function(xhr, ajaxOptions, thrownError) {
		showMessage( "Erro: " + xhr.status + " - " + thrownError + "<br>" + xhr.responseText);
	});
}

// ===========================================================================
// Funções gerais
function obtemVersoes() {
	showStatus("Obtendo versão...");

	$.ajax({
        	url: agent_url+"/getVersion",
		type:"post",
		data: {
			"sessionId":sessao.sessionId,
		},
	})
	.done(function(data) {
		if (data.serviceStatus == 0) {
			showMessage("CliSiTef: [" + data.clisitefVersion + "]<br/>CliSiTefI: [" + data.clisitefiVersion + "]<br/>AgenteCliSiTef: ["+data.serviceVersion+"]");
		}
		else {
			showMessage(data.serviceStatus + " - " + data.serviceMessage);
		}
	})
	.fail(function(xhr, ajaxOptions, thrownError) {
		showMessage( "Erro: " + xhr.status + " - " + thrownError + "<br>" + xhr.responseText);
	});
}

// ===========================================================================
// TEF
// tipo = 1 - Venda simples: a sessão é criada internamente e destruída no final
// tipo = 2 - Venda com sessão: usa-se a sessão criada previamente pela automação
// funcao - código da função na IniciaFuncaoSiTefInterativo
function inicio(tipo, funcao) {
	var ret=[];
	sessao.ret=ret;
	sessao.continua = 0;
	sessao.cupomFiscal = document.getElementById("CUPOMFISCAL").value;
	sessao.dataFiscal = document.getElementById("DATAFISCAL").value;
	sessao.horaFiscal = document.getElementById("HORAFISCAL").value;	

	showStatus("Iniciando transação...");

	var args={};
	if (tipo == 1) {
		// Envia dados para uma nova sessão
		args.sitefIp = document.getElementById("SITEF").value;
		args.storeId = document.getElementById("EMPRESA").value;
		args.terminalId = document.getElementById("TERMINAL").value;
	}
	else if (tipo == 2 && sessao.sessionId) {
		args.sessionId = sessao.sessionId;
	}

	// Argumentos comuns
	args.functionId = funcao;
	args.trnAmount = document.getElementById("VALOR").value;
	args.taxInvoiceNumber = document.getElementById("CUPOMFISCAL").value;
	args.taxInvoiceDate = document.getElementById("DATAFISCAL").value;
	args.taxInvoiceTime = document.getElementById("HORAFISCAL").value;
	args.cashierOperator = document.getElementById("OPERADOR").value;
	args.trnAdditionalParameters = document.getElementById("TRN_PARAMADIC").value;	
	args.trnInitParameters = document.getElementById("SESSAO_PARAMS").value;
		
	
	$.ajax({
        	url: agent_url+"/startTransaction",
		type:"post",
		data: jQuery.param(args),
	})
	.done(function(data) {
		if (data.serviceStatus != 0) {
			showMessage("Agente ocupado: " + data.serviceStatus + " " + data.serviceMessage);
		}
		else if (data.clisitefStatus != 10000) {
			showMessage("Retorno " +data.clisitefStatus+" da CliSiTef");
		}
		else {
			// Inicia retornou 10000 (via clisitef)
			sessao.continua = 0;
			
			// Salva a sessionId para usar na confirmacao
			sessao.sessionId = data.sessionId;
			
			// Continua no fluxo de coleta
			continua("");
		}
	})
	.fail(function(xhr, ajaxOptions, thrownError) {
		showMessage( "Erro: " + xhr.status + " - " + thrownError + "<br>" + xhr.responseText + "<br>" + jQuery.param(args));
	});
}

function finaliza(confirma, reenviaParametrosSiTef, foraDoFluxo) {
	var args = {
		"confirm":confirma,
	};

	if (reenviaParametrosSiTef) {
		args.sitefIp = document.getElementById("SITEF").value;
		args.storeId = document.getElementById("EMPRESA").value;
		args.terminalId = document.getElementById("TERMINAL").value;
		args.taxInvoiceNumber = document.getElementById("CUPOMFISCAL").value;
		args.taxInvoiceDate = document.getElementById("DATAFISCAL").value;
		args.taxInvoiceTime = document.getElementById("HORAFISCAL").value;
	} else {
		args.sessionId = sessao.sessionId;
		args.taxInvoiceNumber = sessao.cupomFiscal || document.getElementById("CUPOMFISCAL").value;
		args.taxInvoiceDate = sessao.dataFiscal || document.getElementById("DATAFISCAL").value;
		args.taxInvoiceTime = sessao.horaFiscal || document.getElementById("HORAFISCAL").value;
	}

	$.ajax({
		url: agent_url+"/finishTransaction",
		type:"post",
		data: args,
	})
	.done(function(data) {
		if (data.serviceStatus != 0) {
			alert(data.serviceStatus + " " + data.serviceMessage);
			location.reload();
		} else {
			if (foraDoFluxo) {
				showStatus("finishTransaction");
				showMessage(
					"serviceStatus:" + data.serviceStatus + "<br>" +
					"clisitefStatus:"+data.clisitefStatus);
			}
		}
	})
	.fail(function(xhr, ajaxOptions, thrownError) {
		showMessage( "Erro: " + xhr.status + " - " + thrownError + "<br>" + xhr.responseText);
	});
}

function continua(dados) {
	// lembrete: chamada ajax é assincrona, então sai da função continua imediatamente
	$.ajax({
		url: agent_url+"/continueTransaction",
		type:"post",
		data:{
			"sessionId":sessao.sessionId,
			"data":dados,
			"continue":sessao.continua,
		},
	})
	.done(function(data) {
		/*console.log("Continua Status=" + data.clisitefStatus + 
			" Dados=" + data.data +
			" Comando=" + data.commandId +
			" TipoCampo=" + data.fieldId +
			" TamMin=" + data.fieldMinLength + 
			" TamMax=" + data.fieldMaxLength);*/
		if (data.serviceStatus != 0) {
			showMessage(data.serviceStatus + " " + data.serviceMessage);
			return;
		}
		
		if (data.clisitefStatus != 10000) {
			var s = "";

			if (data.clisitefStatus == 0) {
				s = JSON.stringify(sessao.ret);
				console.log(s);
				s = s.replace(/},{/g,"},<br>{");
				finaliza(1, false, false);
			}
			showMessage("Fim - Retorno: " + data.clisitefStatus + "<br>" + s);
			return;
		}
		
		document.getElementById("tef_corpo").style.display="none";
		
		if (data.commandId != 23) {
			// tratamento para nao piscar a tela (refresh)
			lastContents23 = '';
		}
		switch(data.commandId)
		{
			case 0:
				var item={
					"TipoCampo": data.fieldId,
					"Valor": data.data
				};
				// acumula o resultado em um JSON, pode ser usado no final da transação para POST ao servidor da automação
				sessao.ret.push(item);
				// console.info("TipoCampo [" + data.fieldId + "] Valor[" + data.data + "]");
				
				if (data.fieldId == 121)
					alert("Cupom Estabelecimento: \n" + data.data);

				if (data.fieldId == 122)
					alert("Cupom Cliente: \n" + data.data);
				//alert("TipoCampo = " + data.fieldId + " " + data.data);
				continua("");
				break;

			case 1:
			case 2:
			case 3:
			case 4:
			case 15:
				document.getElementById("tef_titulo").innerHTML = data.data;
				continua("");
				break;
				
			case 11:
			case 12:
			case 13:
			case 14:
			case 16:
				//Apaga display
				document.getElementById("tef_titulo").innerHTML = "";
				continua("");
				break;
				
			case 22:
				alert(data.data + "\nPressione enter");
				continua("");
			  	break;
			  	
			case 23:
				var contents = "<table><tr><td width=\"150\"><input type=\"BUTTON\" class=\"btn1\" value=\"Cancelar\" onclick=\"sessao.continua=-1;\"/></td></tr></table>";
				if (lastContents23 != contents) {
					document.getElementById("tef_corpo").innerHTML = contents;
					lastContents23 = contents;
				}
				document.getElementById("tef_corpo").style.display="block";
				
				// No comando 23, faz o reset da flag de continuidade, para sensibilizar tratamento de confirmações de cancelamento da clisitef.
				setTimeout(function() { continua(""); sessao.continua=0; }, 500);
			  	break;
			  	
			case 20:
				document.getElementById("tef_titulo").innerHTML = data.data;
				document.getElementById("tef_corpo").innerHTML = "<table><tr><td><input type=\"BUTTON\" class=\"btn1\" value=\"Sim\" onclick=\"continua(0);\"/></td>" +
					"<td><input type=\"BUTTON\" class=\"btn1\" value=\"N&atilde;o\" onclick=\"continua(1);\"/></td></tr></table>";
				document.getElementById("tef_corpo").style.display="block";
				break;
				
			case 21:
			case 30:
			case 31:
			case 32:
			case 33:
			case 34:
			case 35:
			case 38:
				var s = data.data;
				if (data.commandId == 21)
					s = s.replace(/;/g,"<br/>");
				document.getElementById("tef_corpo").innerHTML = "<table><tr><td colspan=\"2\">" + s + "</td></tr><tr><td colspan=\"2\"><input type=\"text\" id=\"DADOS\" onkeypress=\"trataTecla(event);\"/></td></tr>" + 
					"<tr><td><input type=\"BUTTON\" class=\"btn1\" value=\"OK\" onclick=\"trataColeta(0);\"/></td>" +
					"<td><input type=\"BUTTON\" class=\"btn1\" value=\"Cancelar\" onclick=\"trataColeta(-1);\"/></td></tr></table>";
				document.getElementById("tef_corpo").style.display="block";
				setTimeout(function(){ document.getElementById("DADOS").focus(); }, 100);
				break;
				
			default:
				document.getElementById("tef_corpo").innerHTML = "Chegou uma captura desconhecida.[" +  data.commandId + "]";
				document.getElementById("tef_corpo").style.display="block";
				continua("");
		}
	
	})
	.fail(function(xhr, ajaxOptions, thrownError) {
		showMessage( "Erro: " + xhr.status + " - " + thrownError + "<br>" + xhr.responseText);
	});
}

function trataTecla(event) {
	if(event.keyCode == 0x0d)
		trataColeta(0);
}

function trataColeta(cont) {
	sessao.continua=cont;
	continua(document.getElementById("DADOS").value);
}

// ===========================================================================
// Funcoes de PinPad

function pinpadAbre() {
	showStatus("Abrindo pinpad...");

	$.ajax({
        	url: agent_url+"/pinpad/open",
		type:"post",
		data:{
			"sessionId":sessao.sessionId,
		},
	})
	.done(function(data) {
		if (data.serviceStatus != 0) {
			showMessage(data.serviceStatus + " - " + data.serviceMessage);
		}
		else if (data.clisitefStatus == 0){
			showMessage("PinPad aberto com sucesso");
		}
		else{
			showMessage("Retorno " + data.clisitefStatus + " da CliSiTef");
		}
	})
	.fail(function(xhr, ajaxOptions, thrownError) {
		showMessage( "Erro: " + xhr.status + " - " + thrownError + "<br>" + xhr.responseText);
	});
}

function pinpadFecha() {
	showStatus("Fechando pinpad...");

	$.ajax({
        	url: agent_url+"/pinpad/close",
		type:"post",
		data:{
			"sessionId":sessao.sessionId,
		},
	})
	.done(function(data) {
		if (data.serviceStatus != 0) {
			showMessage(data.serviceStatus + " - " + data.serviceMessage);
		}
		else if (data.clisitefStatus == 0) {
			showMessage("PinPad fechado com sucesso");
		}
		else {
			showMessage("Retorno " +data.clisitefStatus+" da CliSiTef");
		}
	})
	.fail(function(xhr, ajaxOptions, thrownError) {
		showMessage( "Erro: " + xhr.status + " - " + thrownError + "<br>" + xhr.responseText);
	});
}

function pinpadPresente() {
	showStatus("Verificando presença do pinpad...");

	$.ajax({
        	url: agent_url+"/pinpad/isPresent",
		type:"post",
		data:{
			"sessionId":sessao.sessionId,
		},
	})
	.done(function(data) {
		showStatus("Presença do pinpad");
		
		if (data.serviceStatus != 0) {
			showMessage(data.serviceStatus + " - " + data.serviceMessage);
		}
		else if (data.clisitefStatus == 0) {
			showMessage("PinPad ausente");
		}
		else if (data.clisitefStatus == 1) {
			showMessage("PinPad presente");
		}
		else {
			showMessage("Retorno " +data.clisitefStatus+" da CliSiTef");
		}
	})
	.fail(function(xhr, ajaxOptions, thrownError) {
		showMessage( "Erro: " + xhr.status + " - " + thrownError + "<br>" + xhr.responseText);
	});
}

function pinpadMensagem(mensagem,persistente) {
	showStatus("Escrevendo mensagem no pinpad...");

	$.ajax({
        	url: agent_url+"/pinpad/setDisplayMessage",
		type:"post",
		data:{
			"sessionId":sessao.sessionId,
			"displayMessage":mensagem,
			"persistent":(persistente?'Y':'N'),
		},
	})
	.done(function(data) {
		if (data.serviceStatus != 0) {
			showStatus("Mensagem no pinpad");
			showMessage(data.serviceStatus + " - " + data.serviceMessage);
		}
		else {
			resetView();
		}
	})
	.fail(function(xhr, ajaxOptions, thrownError) {
		showMessage( "Erro: " + xhr.status + " - " + thrownError + "<br>" + xhr.responseText);
	});
}

function pinpadLeSimNao(mensagem) {
	showStatus("Obtendo escolha no pinpad...");

	$.ajax({
        	url: agent_url+"/pinpad/readYesNo",
		type:"post",
		data:{
			"sessionId":sessao.sessionId,
			"displayMessage":mensagem,
		},
	})
	.done(function(data) {
		if (data.serviceStatus != 0) {
			showStatus("Retorno do pinpad");
			showMessage(data.serviceStatus + " - " + data.serviceMessage);
		}
		else if (data.clisitefStatus == 0) {
			showMessage("Tecla Anula pressionada");
		}
		else if (data.clisitefStatus == 1) {
			showMessage("Tecla Entra pressionada");
		}
		else {
			showMessage("Retorno " +data.clisitefStatus+" da CliSiTef");
		}
	})
	.fail(function(xhr, ajaxOptions, thrownError) {
		showMessage( "Erro: " + xhr.status + " - " + thrownError + "<br>" + xhr.responseText);
	});
}
