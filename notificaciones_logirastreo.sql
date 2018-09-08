sp_configure 'show advanced options', 1;  
GO  
RECONFIGURE;  
GO  
sp_configure 'Ole Automation Procedures', 1;  
GO  
RECONFIGURE;  
GO  

ALTER TABLE recibos1_2000
  ADD id_viaje_logirastreo varchar(10);
GO

--Se eliminan todos los objetos que se crearan posteriormente para evitar errores de objetos existentes
DROP PROCEDURE DBO.LOGIRASTREO_CREAR_VIAJE;
DROP PROCEDURE DBO.LOGIRASTREO_MODIFICAR_VIAJE;
DROP PROCEDURE DBO.LOGIRASTREO_ELIMINAR_VIAJE;
DROP TRIGGER DBO.LOGIRASTREO_CREAR_VIAJE_TRIGGER;
--DROP TRIGGER DBO.LOGIRASTREO_MODIFICAR_VIAJE_TRIGGER;
DROP TRIGGER DBO.LOGIRASTREO_ELIMINAR_VIAJE_TRIGGER;
GO

--Procedimiento almacenado para notificar a logirastreo que un viaje se crea
CREATE PROCEDURE LOGIRASTREO_CREAR_VIAJE(@numero char(12), @idRuta char(20), @placa char(7), @idConductor char(10), @fechaInicio datetime, @hora char(5))
AS
BEGIN
    Declare @Object as Int;
	Declare @fechaHoraInicio as CHAR(20);
	Declare @url as varchar(255);
    Declare @ResponseText as Varchar(8000);
	
	SET @fechaInicio = CONVERT(CHAR, CONVERT(CHAR, @fechaInicio));
	SET @fechaHoraInicio = CONVERT(CHAR, @fechaInicio + ' ' + @hora, 120);
	SET @url = REPLACE(CONCAT('http://logirastreo.com/creaViajesBusesWeb.php?idRuta=', @idRuta, '&placa=', @placa, '&idConductor=', @idConductor, '&fechaInicio='), ' ', '') + @fechaHoraInicio;
    Exec sp_OACreate 'MSXML2.XMLHTTP', @Object OUT;
    Exec sp_OAMethod @Object, 'open', NULL, 'get', @url,'false'
    Exec sp_OAMethod @Object, 'send'
    Exec sp_OAMethod @Object, 'responseText', @ResponseText OUTPUT
    Select 'Logirastreo respondió con ' + @ResponseText
	UPDATE recibos1_2000 SET id_viaje_logirastreo = @ResponseText WHERE @numero = numero;
    Exec sp_OADestroy @Object
END
GO

--Procedimiento almacenado para notificar a logirastreo que un viaje se modifica
CREATE PROCEDURE LOGIRASTREO_MODIFICAR_VIAJE(@numero char(12), @idRuta char(20), @placa char(7), @idConductor char(10), @fechaInicio datetime, @hora char(5), @idViajeEliminar VARCHAR(8000) )
AS
BEGIN
    Declare @Object as Int;
	Declare @fechaHoraInicio as CHAR(20);
	Declare @url as VARCHAR(255);
    Declare @ResponseText as VARCHAR(8000);

	
	SET @fechaInicio = CONVERT(CHAR, CONVERT(CHAR, @fechaInicio));
	SET @fechaHoraInicio = CONVERT(CHAR, @fechaInicio + ' ' + @hora, 120);
	SET @url = REPLACE('http://logirastreo.com/modificaViajesBusesWeb.php?idRuta=' + @idRuta + '&placa=' + @placa + '&idConductor=' + @idConductor + 
		'&fechaInicio=' + @fechaHoraInicio + '&idViajeEliminar=' + @idViajeEliminar, ' ', '');
    Exec sp_OACreate 'MSXML2.XMLHTTP', @Object OUT;
    Exec sp_OAMethod @Object, 'open', NULL, 'get', @url,'false'
    Exec sp_OAMethod @Object, 'send'
    Exec sp_OAMethod @Object, 'responseText', @ResponseText OUTPUT
	SELECT @ResponseText
    Exec sp_OADestroy @Object
END
GO

--Procedimiento almacenado para notificar a logirastreo que un viaje se elimina
CREATE PROCEDURE LOGIRASTREO_ELIMINAR_VIAJE(@idViajeEliminar VARCHAR(8000))
AS
BEGIN
    Declare @Object as Int;
	Declare @url as varchar(255);
    Declare @ResponseText as Varchar(8000);

	SET @url = REPLACE('http://logirastreo.com/eliminarViajesBusesWeb.php?idViajeEliminar=' + @idViajeEliminar, ' ', '');
    Exec sp_OACreate 'MSXML2.XMLHTTP', @Object OUT;
    Exec sp_OAMethod @Object, 'open', NULL, 'get', @url,'false'
    Exec sp_OAMethod @Object, 'send'
    Exec sp_OAMethod @Object, 'responseText', @ResponseText OUTPUT  
	SELECT 'Se notificó a Logirastreo'
    Exec sp_OADestroy @Object
END
GO

--Trigger para notificar la creación de un viaje
CREATE TRIGGER LOGIRASTREO_CREAR_VIAJE_TRIGGER  
ON dbo.recibos1_2000  
AFTER INSERT AS
	DECLARE @numero char(12), 
	@idRuta char(20), 
	@placa char(7), 
	@idConductor char(10), 
	@fechaInicio datetime, 
	@hora char(5)
	SELECT @numero =  a.numero, @placa = v.PLACADOS, @idConductor =  a.CEDCONDUCTOR, @idRuta =  a.RUTA, @hora = a.HORA, @fechaInicio = a.FECHASALIDA
		FROM     INSERTED AS a INNER JOIN                         
                 proveedores AS p ON a.CEDCONDUCTOR = p.nit INNER JOIN
                 vehiculos AS v ON a.PLACA = v.placa INNER JOIN
                 RUTAS ON a.RUTA = RUTAS.RUTA;

    EXEC LOGIRASTREO_CREAR_VIAJE @numero, @idRuta, @placa, @idConductor, @fechaInicio, @hora;      
    
GO  

/*
--Trigger para la notificación de modificación de un viaje
CREATE TRIGGER LOGIRASTREO_MODIFICAR_VIAJE_TRIGGER  
ON dbo.recibos1_2000  
AFTER UPDATE AS
	DECLARE @numero char(12), 
	@idRuta char(20), 
	@placa char(7), 
	@idConductor char(10), 
	@fechaInicio datetime, 
	@hora char(5),
	@idViajeEliminar VARCHAR(8000)
	
	SELECT @numero =  a.numero, @placa = v.PLACADOS, @idConductor =  a.CEDCONDUCTOR, @idRuta =  a.RUTA, @hora = a.HORA, @fechaInicio = a.FECHASALIDA, @idViajeEliminar = a.id_viaje_logirastreo
		FROM     INSERTED AS a INNER JOIN                         
                 proveedores AS p ON a.CEDCONDUCTOR = p.nit INNER JOIN
                 vehiculos AS v ON a.PLACA = v.placa INNER JOIN
                 RUTAS ON a.RUTA = RUTAS.RUTA;

    EXEC LOGIRASTREO_MODIFICAR_VIAJE @numero, @idRuta, @placa, @idConductor, @fechaInicio, @hora, @idViajeEliminar;      
    
GO  
*/

--Trigger para notificar que se anuló un viaje
CREATE TRIGGER LOGIRASTREO_ELIMINAR_VIAJE_TRIGGER  
ON dbo.recibos1_2000  
AFTER UPDATE AS
	DECLARE @anulado int,
	@idViajeEliminar VARCHAR(8000)

	SELECT @anulado = a.anulado, @idViajeEliminar = a.id_viaje_logirastreo
		FROM     INSERTED AS a ;
	IF @anulado = 1
		EXEC LOGIRASTREO_ELIMINAR_VIAJE @idViajeEliminar;
GO
