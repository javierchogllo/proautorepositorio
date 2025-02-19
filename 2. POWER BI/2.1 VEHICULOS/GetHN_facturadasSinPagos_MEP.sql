USE [DWH_Proauto]
GO
/****** Object:  StoredProcedure [dbo].[GetHN_facturadasSinPagos_MEP]    Script Date: 22/10/2024 10:38:49 a. m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-----------------------------------------------------------------------------------------------------------------------
-- CREADO POR:  MQR
-- DESCRIPCION: Reporte que visualiza las Facturas con HN que no han recibido pagos mayores a $1000
-- HISTORIAL:   <2024-10-22> Se modifica la bodega de las facturas/HNs de acuerdo al tipo de documento JCB
--              <2024-10-22> Se agrega el campo Marca y Modelo JCB
-----------------------------------------------------------------------------------------------------------------------

--exec [dbo].[GetHN_facturadasSinPagos_MEP]
alter PROCEDURE [dbo].[GetHN_facturadasSinPagos_MEP]
as
	--saca solo Hn facturas q no tengan Formas de Pago registradas
	select x.*
	into #hn_facturadas
	from (
		Select id_hn=hn.id
			   ,hn.fecha
			   ,Nro_formaPago=(select count(valor) 
							   from [dms_smd3].dbo.veh_hn_forma_pago ff with(nolock)
							   where ff.id_veh_hn_enc=hn.id)
			   ,Tercero=cli.razon_social
			   --,Bodega=b.descripcion
			   ,id_bodega=b.id
			   ,asesor=u.nombre,
			   t.descripcion as tipo_documento,
			   cc.id as id_factura,
			   cc.anulada,
			   fecha_factura = cc.fecha,
			   Marca = vi.Marca,
			   Modelo = ci.descripcion,
			   fila = RANK() over(partition by hn.id order by cc.fecha desc, cc.id desc)
		from [dms_smd3].dbo.veh_hn_enc hn
		join [dms_smd3].[dbo].[cot_cotizacion] cc on (cc.id_veh_hn_enc = hn.id)
		join [dms_smd3].[dbo].[cot_cotizacion_item] cci on (cc.id = cci.id_cot_cotizacion)
		join [dms_smd3].[dbo].[cot_item] ci on (cci.id_cot_item = ci.id)
		join [dms_smd3].[dbo].[cot_item_lote] l on (l.id = cci.id_cot_item_lote)
		JOIN [dms_smd3].[dbo].[v_cot_item_descripcion] vi  ON vi.id = ci.id  
		-----------
		join [dms_smd3].[dbo].[cot_tipo] t on t.id = cc.id_cot_tipo
		join [dms_smd3].dbo.cot_bodega b on b.id=cc.id_cot_bodega
		join [dms_smd3].dbo.usuario u on u.id=hn.id_usuario_vende
		join [dms_smd3].dbo.cot_cliente_contacto co on co.id=hn.id_cot_cliente_contacto
		join [dms_smd3].dbo.cot_cliente cli on cli.id=co.id_cot_cliente
		where hn.estado in (500,550)
		and (select count(valor) from [dms_smd3].dbo.veh_hn_forma_pago f where f.id_veh_hn_enc=hn.id)=0
		and cast(hn.fecha as date) >= '2024-01-01'
		and t.sw in (1)
		--and hn.id = 38870
		--order by hn.fecha
	)x
	where x.fila = 1

	--actualizamos la bodega de acuerdo al tipo de documento (esto por ejemplo, para ventas en zona1 que son de GYE)
	update hn set hn.id_bodega = case when hn.tipo_documento='FA.17.1.1.Z2 - FACT. QTO GRANADOS VEH ZONA 2 GYE A' then 1257
			                          when hn.tipo_documento='NC.17.1.1.Z2-NOTA CRED QTO GRANADOS VEH Z2 GYE AME' then 1257
		                              when hn.tipo_documento='NC.17.1.1.Z2-NOTA CRED QTO GRANADOS VEH Z2 DAULE' then 1267
			                          when hn.tipo_documento='FA.17.1.1.Z2 - FACT. QTO GRANADOS VEH ZONA 2 DAULE' then 1267
			                          when hn.tipo_documento='FA.17.1.1.Z2 - FACT. QTO GRANADOS VEH ZONA 2 MCH T' then 1252
			                          when hn.tipo_documento='NC.17.1.1.Z2-NOTA CRED QTO GRANADOS VEH Z2 MCH TER' then 1252			 
			                          when hn.tipo_documento='FA.17.7.1.Z2 - FACT. QTO RUSIA VEH ZONA 2 C.SEXTA' then 1275
			                          when hn.tipo_documento='NC.17.7.1.Z2-NOTA CRED QTO RUSIA VEH Z2 C SEXTA' then 1275		 
			                          when hn.tipo_documento='FA.17.1.1.Z3 - FACT. QTO GRANADOS VEH ZONA 3 CUE E' then 1181
			                          when hn.tipo_documento='NC.17.1.1.Z3-NOTA CRED QTO GRANADOS VEH Z3 CUE ESP' then 1181
									  --Ventas de Machala con placa de Guayaquil (07.2.1 - MCH TERM. TERRESTRE VEH 1252)
									  when hn.tipo_documento='FA.09.1.1 - FACT. GYE  AMERICAS VEH CC AG MACHALA' then 1252
									  when hn.tipo_documento='NC.09.1.1.-NOTA CRED GYE AMERICAS VEH CC MACHALA' then 1252
                                      else hn.id_bodega							
								end
	from #hn_facturadas hn



	--Saca la ultima factura en caso de tener 2 o mas facturas la HN
	select 
		id_factura=max(c.id)
		,f.id_hn
		--,f.Bodega
		,f.Tercero
		,f.fecha
		,f.Nro_formaPago
		,f.id_bodega
		,f.asesor
		,f.tipo_documento
		,f.Marca
		,f.Modelo
	into #Facturas
	from #hn_facturadas f
	join [dms_smd3].dbo.cot_cotizacion c on c.id_veh_hn_enc=f.id_hn
	join [dms_smd3].dbo.cot_tipo t on t.id=c.id_cot_tipo and t.sw=1
	group by f.id_hn
		--,f.Bodega
		,f.Tercero
		,f.fecha
		,f.Nro_formaPago
		,f.id_bodega
		,f.asesor
		,f.tipo_documento
		,f.Marca
		,f.Modelo

	--Compara si la factura tiene cruces menores a $1000
	select fac.id_factura
			,hn=fac.id_hn
			,fac.fecha
			--,fac.Bodega
			,fac.Tercero
			,c.total_total
			,valor_aplicado=sum(cr.valor_aplicado)
			,saldo_factura=c.total_total-sum(isnull(cr.valor_aplicado,0))
			,fac.Nro_formaPago
			,fac.id_bodega
			,fac.asesor
			,fac.tipo_documento
			,fac.Marca
			,fac.Modelo
	--into [DWH_Proauto].[dbo].[FacturadasSinPagosMEP] 
	from #Facturas fac
	join [dms_smd3].dbo.cot_cotizacion c on c.id=fac.id_factura
	left join [dms_smd3].dbo.cot_recibo_cruce cr on cr.id_cot_cotizacion=fac.id_factura
	group by 
		fac.id_factura
		,fac.id_hn
		--,fac.Bodega
		,fac.Tercero
		,c.total_total
		,fac.fecha
		,fac.Nro_formaPago
		,fac.id_bodega
		,fac.asesor
		,fac.tipo_documento
		,fac.Marca
	    ,fac.Modelo
	having sum(isnull(cr.valor_aplicado,0))<1000
	and c.total_total-sum(isnull(cr.valor_aplicado,0))>0
	order by fac.fecha