/*
	Library: chart
	Author: neovis
	https://github.com/neovis22/chart

	Modified: jNizM
*/

chart(hwnd := "", type := "Bar") {
	return new Charter(hwnd, type)
}

class Charter extends Charter.Box {

	static debugmode := false

	static charts := {
	(join, ltrim
		Bar: Charter.Bar
		BarV: Charter.Bar
		BarH: Charter.BarH
		Line: Charter.Line
		Scatter: Charter.Scatter
		Bubble: Charter.Bubble
		Pie: Charter.Pie
		Doughnut: Charter.Doughnut
	)}

	static themes := {
	(join ltrim
		light:{
			palette:[0xF33434, 0xC5F433, 0xF39934, 0x6434F3, 0x3499F3, 0xF334C4, 0xF3C832, 0x34F3EF, 0x64F433, 0xC832F3],
			backgroundColor:0xFFFFFF,
			borderColor:0xE2E2E2,
			gridColor:0xE8E8E8,
			color:0x333333
		},
		dark:{
			palette:[0xD30C0C, 0xA3D50B, 0xD3750C, 0x3E0CD3, 0xC75D3, 0xD30CA2, 0xD1A50C, 0xCD3CE, 0x3ED50B, 0xA50CD1],
			backgroundColor:0x202020,
			borderColor:0x333333,
			gridColor:0x444444,
			color:0xFFFFFF
		}
	)}

	_paletteOffset := 0

	_title := new Charter.TextRenderer

	datasets := []

	xAxis := new Charter.Axis

	yAxis := new Charter.Axis

	font := "Segoe UI"

	__new(hwnd, type) {
		if (hwnd)
			WinSet Style, +0xE, % "ahk_id" hwnd

		this.bar := []

		this.hwnd := hwnd
		this.type := type

		this.theme("light")
		this.margin(6, 10)

		this.title.fontSize := 18
		this.title.options := "Bold"
		this.title.align := "Center"
		this.title.padding(8)
	}

	__delete() {
		if (this._hgui && WinExist("ahk_id" this._hgui))
			Gui % this._hgui ":Destroy"
	}

	_color() {
		if (this._paletteOffset == this.palette.length())
			this._paletteOffset := 0
		return this.palette[++ this._paletteOffset]
	}

	theme(theme, paletteShuffle := false) {
		if !(this.themes[theme])
			throw Exception("unknown theme: " theme)

		for k, v in this.themes[theme]
			this[StrSplit(k, ".")*] := IsObject(v) ? v.clone() : v

		if (paletteShuffle)
			this.shufflePalette()
		return this
	}

	shufflePalette() {
		loop % length := this.palette.length() {
			Random i, 1, length
			temp := this.palette[A_Index]
			this.palette[A_Index] := this.palette[i]
			this.palette[i] := temp
		}
		return this
	}

	data(data, options := "") {
		dataset := []
		if (IsObject(options))
			for k, v in options
				dataset[k] := v
		dataset.data := data
		return this, this.datasets.push(dataset)
	}

	grid(xCount := "", yCount := "") {
		if (xCount != "")
			this.xAxis.gridCount := xCount
		if (yCount != "")
			this.yAxis.gridCount := yCount
		return this
	}

	at(x, y) {
		switch (this.type) {
			case "Bar", "BarV", "BarH":
				for i, elem in this.elements
					if (elem.x <= x && elem.y <= y && elem.x + elem.width >= x && elem.y + elem.height >= y)
						return elem.value
			case "Line":
				for i, elem in this.elements {
					dist := Sqrt(Abs(x - elem.x) **2 + Abs(y - elem.y) **2)
					if (min == "" || min > dist)
						if ((min := dist) < 10)
							res := elem.value
				}
		}
		return res
	}

	plot() {
		if (this.hwnd == "" || !WinExist("ahk_id" this.hwnd)) {
			defaultGui := a_defaultGui
			defaultListView := a_defaultListView
			defaultTreeView := a_defaultTreeView
			width := this.width ? this.width : 600
			height := this.height ? this.height : 400

			Gui New, +Hwndhwnd +LabelChartGui
			this._hgui := hwnd
			Gui Margin, 0, 0
			Gui Add, Text, % "xm w" width " h" height " +0xE Hwndhwnd"
			this.hwnd := hwnd
		}

		width := this.width
		height := this.height

		VarSetCapacity(rc, 16)
		if !(DllCall("GetClientRect", "Ptr", this.hwnd, "Ptr", &rc))
			throw Exception("target hwnd is invalid")
		if (this.width == 0)
			this.width := NumGet(rc, 8, "Int")
		if (this.height == 0)
			this.height := NumGet(rc, 12, "Int")

		DllCall("gdiplus\GdipCreateBitmapFromScan0", "Int", this.width, "Int", this.height, "Int", 0, "Int", 0x26200A, "UPtr", 0, "UPtr*", pbm)
		DllCall("gdiplus\GdipGetImageGraphicsContext", "UPtr", pbm, "UPtr*", pg)
		DllCall("gdiplus\GdipSetSmoothingMode", "UPtr", pg, "Int", 4)
		DllCall("gdiplus\GdipSetTextRenderingHint", "UPtr", pg, "Int", 4)

		this.render(pg)

		DllCall("gdiplus\GdipCreateHBITMAPFromBitmap", "UPtr", pbm, "UPtr*", hbm, "Int", 0xffffffff)
		msg := DllCall("SendMessage", "UPtr", this.hwnd, "UInt", 0x172, "UInt", 0x0, "UPtr", hbm)
		DllCall("DeleteObject", "UPtr", msg)
		DllCall("DeleteObject", "UPtr", hbm)
		DllCall("gdiplus\GdipDisposeImage", "UPtr", pbm)
		DllCall("gdiplus\GdipDeleteGraphics", "UPtr", pg)

		this.width := width
		this.height := height

		if (hwnd) {
			Gui Show,, % this.title.text == "" ? "Chart" : this.title.text

			if (defaultGui) {
				Gui % defaultGui ":Default"
				if (defaultListView)
					Gui % defaultGui "ListView", % defaultListView
				if (defaultTreeView)
					Gui % defaultGui "TreeView", % defaultTreeView
			}
		}
		return this
	}

	render(g) {
		if !(Charter.charts[this.type])
			throw Exception("unsupported type: " this.type)

		this.elements := []

		chart := new Charter.charts[this.type]
		chart.parent := this
		chart.render(g)
		return this
	}

	save(path, width := "", height := "", quality := 100) {
		w := this.width
		h := this.height

		if (width != "")
			this.width := width
		if (height != "")
			this.height := height

		DllCall("gdiplus\GdipCreateBitmapFromScan0", "Int", this.width, "Int", this.height, "Int", 0, "Int", 0x26200A, "UPtr", 0, "UPtr*", pbm)
		DllCall("gdiplus\GdipGetImageGraphicsContext", "UPtr", pbm, "UPtr*", pg)
		this.render(pg)
		this.SaveBitmapToFile(pbm, path, quality)
		DllCall("gdiplus\GdipDeleteGraphics", "UPtr", pg)
		DllCall("gdiplus\GdipDisposeImage", "UPtr", pbm)

		this.width := w
		this.height := h
		return this
	}

	SaveBitmapToFile(pBitmap, sOutput, Quality := 75)
	{
		nCount := 0
		nSize := 0
		_p := 0

		SplitPath sOutput,,, Extension
		if !(RegExMatch(Extension, "^(?i:BMP|DIB|RLE|JPG|JPEG|JPE|JFIF|GIF|TIF|TIFF|PNG)$"))
			return -1
		Extension := "." Extension

		DllCall("gdiplus\GdipGetImageEncodersSize", "UInt*", nCount, "UInt*", nSize)
		VarSetCapacity(ci, nSize)
		DllCall("gdiplus\GdipGetImageEncoders", "UInt", nCount, "UInt", nSize, "UPtr", &ci)
		if !(nCount && nSize)
			return -2

		loop % nCount {
			sString := StrGet(NumGet(ci, (idx := (48 + 7 * A_PtrSize) * (A_Index - 1)) + 32 + 3 * A_PtrSize), "UTF-16")
			if !(InStr(sString, "*" Extension))
				continue
			pCodec := &ci + idx
			break
		}

		if !(pCodec)
			return -3

		if (Quality != 75) {
			Quality := (Quality < 0) ? 0 : (Quality > 100) ? 100 : Quality
			if (RegExMatch(Extension, "^\.(?i:JPG|JPEG|JPE|JFIF)$"))
			{
				DllCall("gdiplus\GdipGetEncoderParameterListSize", "UPtr", pBitmap, "UPtr", pCodec, "UInt*", nSize)
				VarSetCapacity(EncoderParameters, nSize, 0)
				DllCall("gdiplus\GdipGetEncoderParameterList", "UPtr", pBitmap, "UPtr", pCodec, "UInt", nSize, "UPtr", &EncoderParameters)
				nCount := NumGet(EncoderParameters, "UInt")
				loop % nCount {
					elem := (24 + (A_PtrSize ? A_PtrSize : 4)) * (A_Index - 1) + 4 + (pad := A_PtrSize = 8 ? 4 : 0)
					if (NumGet(EncoderParameters, elem + 16, "UInt") = 1) && (NumGet(EncoderParameters, elem + 20, "UInt") = 6)
					{
						_p := elem + &EncoderParameters - pad - 4
						NumPut(Quality, NumGet(NumPut(4, NumPut(1, _p+0) + 20, "UInt")), "UInt")
						break
					}
				}
			}
		}
		_E := DllCall("gdiplus\GdipSaveImageToFile", "UPtr", pBitmap, "UPtr", &sOutput, "UPtr", pCodec, "UInt", _p ? _p : 0)
		return _E ? -5 : 0
	}

	title[args*] {
		get {
			if (args.length())
				return this, this._title.text := args[1]
			return this._title
		}
		set {
			return this._title.text := value
		}
	}

	type[args*] {
		get {
			if (args.length())
				return this, this._type := args[1]
			return this._type
		}
		set {
			return this._type := value
		}
	}

	labels[args*] {
		get {
			if (args.length())
				return this, this._labels := args[1]
			return this._labels
		}
		set {
			return this._labels := value
		}
	}

	class Axis {

		_title := new Charter.TextRenderer

		_labels := []

		_format := ""

		_formatter := ""

		label := new Charter.TextRenderer

		gridWidth := 1
		gridColor := ""
		gridCount := ""

		min := ""
		max := ""

		__new() {
			this.title.fontSize := 15
			this.title.options := "Bold"
			this.title.align := "Center"
			this.title.padding(6)
		}

		range(min := "", max := "") {
			if (min != "")
				this.min := min
			if (max != "")
				this.max := max
			return this
		}

		grid(count := "", width := "", color := "") {
			if (count != "")
				this.gridCount := count
			if (width != "")
				this.gridWidth := width
			if (color != "")
				this.gridColor := color
			return this
		}

		title[args*] {
			get {
				if (args.length())
					return this, this._title.text := args[1]
				return this._title
			}
			set {
				return this._title.text := value
			}
		}

		labels[args*] {
			get {
				if (args.length())
					return this, this._labels := args[1]
				return this._labels
			}
			set {
				return this._labels := value
			}
		}

		format[args*] {
			get {
				if (args.length())
					return this, this._format := args[1]
				return this._format
			}
			set {
				return this._format := value
			}
		}

		formatter[args*] {
			get {
				if (args.length())
					return this, this._formatter := args[1]
				return this._formatter
			}
			set {
				return this._formatter := value
			}
		}
	}

	class Bar extends Charter.ChartRenderer {

		drawChart(g) {
			chart := this.parent
			rect := this.contentRect
			barW := chart.bar.width
			if (barW == "")
				barW := 0.6

			for i, dataset in chart.datasets {
				if (dataset.yKey != "")
					keys := StrSplit(dataset.yKey, ".")

				size := this.isHorizontal ? rect.height / this.count : rect.width / this.count
				margin := barW < 1 ? size * (0.5 - barW / 2) : (size - barW * chart.datasets.count()) / 2
				x := y := 0
				w := h := (size - margin * 2) / chart.datasets.count()
				offset := margin + w * (A_Index - 1)

				DllCall("gdiplus\GdipCreateSolidFill", "UInt", this.argb(dataset.color), "UPtr*", brush)
				for i, value in dataset.data {
					v := keys ? value[keys*] : value
					if (this.isHorizontal) {
						y := offset + size * (A_Index - 1)
						w := (v - this.min.y) / this.range.y * rect.width
					} else {
						x := offset + size * (A_Index - 1)
						h := (v - this.min.y) / this.range.y * rect.height
						y := rect.height - h
					}
					chart.elements.push({x:rect.x + x, y:rect.y + y, width:w, height:h, value:value})
					DllCall("gdiplus\GdipFillRectangle", "UPtr", g, "UPtr", brush, "Float", rect.x + x, "Float", rect.y + y, "Float", w, "Float", h)
					if (A_Index == this.count)
						break
				}
				DllCall("gdiplus\GdipDeleteBrush", "UPtr", brush)
			}
		}
	}

	class BarV extends Charter.Bar {

	}

	class BarH extends Charter.Bar {

		isHorizontal := true
	}

	class Line extends Charter.ChartRenderer {

		drawChart(g) {
			chart := this.parent
			rect := this.contentRect
			for i, dataset in chart.datasets {
				if (dataset.yKey != "")
					keys := StrSplit(dataset.yKey, ".")
				width := dataset.width ? dataset.width : 1
				radius := dataset.radius != "" ? dataset.radius : 4

				size := rect.width/(this.count-1)

				DllCall("gdiplus\GdipCreateSolidFill", "UInt", this.argb(dataset.color), "UPtr*", brush)
				DllCall("gdiplus\GdipCreatePen1", "UInt", this.argb(dataset.color), "Float", width, "Int", 2, "UPtr*", pen)
				for i, value in dataset.data {
					v := keys ? value[keys*] : value
					x1 := rect.x + size * (A_Index - 1)
					y1 := rect.y + rect.height - (v - this.min.y) / this.range.y * rect.height
					chart.elements.push({x:x1, y:y1, value:value})
					if (radius)
						DllCall("gdiplus\GdipFillEllipse", "UPtr", g, "UPtr", brush, "Float", x1 - radius, "Float", y1 - radius, "Float", radius * 2, "Float", radius * 2)
					if (A_Index != 1)
						DllCall("gdiplus\GdipDrawLine", "UPtr", g, "UPtr", pen, "Float", x1, "Float", y1, "Float", x2, "Float", y2)
					x2 := x1, y2 := y1
					if (A_Index == this.count)
						break
				}
				DllCall("gdiplus\GdipDeleteBrush", "UPtr", brush)
				DllCall("gdiplus\GdipDeletePen", "UPtr", pen)
			}
		}
	}

	class Scatter extends Charter.ChartRenderer {

		drawChart(g) {
			chart := this.parent
			rect := this.contentRect
			for i, dataset in chart.datasets {
				xKey := dataset.xKey == "" ? [1] : StrSplit(dataset.xKey, ".")
				yKey := dataset.yKey == "" ? [2] : StrSplit(dataset.yKey, ".")
				radius := dataset.radius ? dataset.radius : Min(8, Max(1, Min(rect.width, rect.height) * 0.013))

				DllCall("gdiplus\GdipCreateSolidFill", "UInt", this.argb(dataset.color), "UPtr*", brush)
				for i, v in dataset.data {
					x := Min(this.max.x, Max(this.min.x, v[xKey*]))
					yval := Min(this.max.y, Max(this.min.y, v[yKey*]))
					x := rect.x + rect.width * (x - this.min.x) / this.range.x
					y := rect.y + rect.height * (yval - this.min.y) / this.range.y
					DllCall("gdiplus\GdipFillEllipse", "UPtr", g, "UPtr", brush, "Float", x - radius, "Float", y - radius, "Float", radius * 2, "Float", radius * 2)
				}
				DllCall("gdiplus\GdipDeleteBrush", "UPtr", brush)
			}
		}
	}

		class Bubble extends Charter.ChartRenderer {

		drawChart(g) {
			chart := this.parent
			rect := this.contentRect
			for i, dataset in chart.datasets {
				xKeys := dataset.xKey == "" ? [1] : StrSplit(dataset.xKey, ".")
				yKeys := dataset.yKey == "" ? [2] : StrSplit(dataset.yKey, ".")
				rKeys := dataset.rKey == "" ? [3] : StrSplit(dataset.rKey, ".")
				color := dataset.color < 0x1000000 ? dataset.color | 0xCC000000 : dataset.color

				radius := Min(rect.width, rect.height) * 0.2
				DllCall("gdiplus\GdipCreateSolidFill", "UInt", color, "UPtr*", brush)
				for i, v in dataset.data {
					x := Min(this.max.x, Max(this.min.x, v[xKeys*]))
					y := Min(this.max.y, Max(this.min.y, v[yKeys*]))
					r := Min(this.max.r, Max(this.min.r, v[rKeys*]))
					x := rect.x + rect.width * (x - this.min.x) / this.range.x
					y := rect.y + rect.height * (y - this.min.y) / this.range.y
					r := radius * (r - this.min.r) / this.range.r
					DllCall("gdiplus\GdipFillEllipse", "UPtr", g, "UPtr", brush, "Float", x - r, "Float", y - r, "Float", r * 2, "Float", r * 2)
				}
				DllCall("gdiplus\GdipDeleteBrush", "UPtr", brush)
			}
		}
	}

	class Pie extends Charter.ChartRenderer {

		drawChart(g) {
			chart := this.parent
			rect := this.contentRect

			lr := new this.LabelRenderer(chart)
			rc := lr.measure(g, "T")
			padding := rc.height * 1.5

			if (rect.width < rect.height) {
				size := rect.width - padding * 2
				offsetX := padding
				offsetY := padding + (rect.height - rect.width) / 2
			} else {
				size := rect.height - padding * 2
				offsetX := padding + (rect.width - rect.height) / 2
				offsetY := padding
			}

			centerX := rect.x + rect.width / 2
			centerY := rect.y + rect.height /2

			textW := (rect.width - size) * 0.4
			lr.width := textW * 2
			lr.height := textW * 2

			for i, dataset in chart.datasets {
				if (dataset.yKey != "")
					keys := StrSplit(dataset.yKey, ".")
				if !(IsObject(dataset.colors))
					dataset.colors := []

				labels := IsObject(dataset.labels) ? dataset.labels : StrSplit(dataset.labels, ",")

				r := (A_Index - 1) / chart.datasets.count() * (size * 0.25)
				x := offsetX + rect.x + r
				y := offsetY + rect.y + r
				w := h := size - r * 2

				DllCall("gdiplus\GdipCreateSolidFill", "UInt", chart.backgroundColor | 0xFF000000, "UPtr*", brush)
				DllCall("gdiplus\GdipCreatePen1", "UInt", this.argb(chart.backgroundColor), "Float", 1, "Int", 2, "UPtr*", pen)
				DllCall("gdiplus\GdipFillEllipse", "UPtr", g, "UPtr", brush, "Float", x, "Float", y, "Float", w, "Float", h)

				total := 0
				for i, v in dataset.data
					total += keys ? v[keys*] : v

				offset := 270
				for i, v in dataset.data {
					if (dataset.colors[i] == "")
						dataset.colors[i] := chart._color()
					if (keys)
						v := v[keys*]
                    angle := v / total * 360

					color := this.argb(dataset.colors[i])
					DllCall("gdiplus\GdipSetSolidFillColor", "UPtr", brush, "UInt", color)
					DllCall("gdiplus\GdipDrawPie", "UPtr", g, "UPtr", pen, "Float", x, "Float", y, "Float", w, "Float", h, "Float", offset, "Float", angle)
					DllCall("gdiplus\GdipFillPie", "UPtr", g, "UPtr", brush, "Float", x, "Float", y, "Float", w, "Float", h, "Float", offset, "Float", angle)

					dist := (size - r * 2) / 2 * 1.1
					a := (offset + angle / 2) * 3.1415926 / 180
					lr.x := centerX + dist * Cos(a) - textW
					lr.y := centerY + dist * Sin(a) - textW
					lr.text := LTrim(labels[i] " " Round(v / total * 100) "%")
					lr.render(g)

					offset += angle
				}
				DllCall("gdiplus\GdipDeleteBrush", "UPtr", brush)
				DllCall("gdiplus\GdipDeletePen", "UPtr", pen)
			}

			if (this.isDoughnut) {
				r := size * 0.75
				x := offsetX + rect.x + r
				y := offsetY + rect.y + r
				w := h := size - r * 2

				DllCall("gdiplus\GdipCreateSolidFill", "UInt", this.argb(chart.backgroundColor), "UPtr*", brush)
				DllCall("gdiplus\GdipFillEllipse", "UPtr", g, "UPtr", brush, "Float", x, "Float", y, "Float", w, "Float", h)
				DllCall("gdiplus\GdipDeleteBrush", "UPtr", brush)
			}
		}

		formatter(value, total) {
			return Trim(this " " Round(value / total * 100) "%")
		}


		class LabelRenderer extends Charter.TextRenderer {

			__new(chart) {
				base.__new("s12 Bold Center vCenter", chart.font)
				this.color := chart.color
				DllCall("gdiplus\GdipCreateSolidFill", "UInt", chart.backgroundColor | 0xFF000000, "UPtr*", bgBrush)
				DllCall("gdiplus\GdipCreatePen1", "UInt", 0x40808080, "Float", 1, "Int", 2, "UPtr*", bgPen)
			}

			__delete() {
				DllCall("gdiplus\GdipDeleteBrush", "UPtr", this.bgBrush)
				DllCall("gdiplus\GdipDeleteBrush", "UPtr", this.bgPen)
				base.__delete()
			}

			render(g) {
				rc := this.measure(g)
				this.FillRoundedRectangle(g, this.bgBrush, rc.x - 5, rc.y - 3, rc.width + 10, rc.height + 5, 3)
				this.DrawRoundedRectangle(g, this.bgPen, rc.x - 5, rc.y - 3, rc.width + 10, rc.height + 5, 3)
				base.render(g)
			}

			FillRoundedRectangle(g, b, x, y, w, h, r) {
				DllCall("gdiplus\GdipCreateRegion", "UInt*", Region)
				DllCall("gdiplus\GdipGetClip", "UPtr", g, "UInt", Region)
				DllCall("gdiplus\GdipSetClipRect", "UPtr", g, "Float", x - r, "Float", y - r, "Float", 2 * r, "Float", 2 * r, "Int", 4)
				DllCall("gdiplus\GdipSetClipRect", "UPtr", g, "Float", x + w - r, "Float", y - r, "Float", 2 * r, "Float", 2 * r, "Int", 4)
				DllCall("gdiplus\GdipSetClipRect", "UPtr", g, "Float", x - r, "Float", y + h - r, "Float", 2 * r, "Float", 2 * r, "Int", 4)
				DllCall("gdiplus\GdipSetClipRect", "UPtr", g, "Float", x + w - r, "Float", y + h - r, "Float", 2 * r, "Float", 2 * r, "Int", 4)
				DllCall("gdiplus\GdipFillRectangle", "UPtr", g, "UPtr", b, "Float", x, "Float", y, "Float", w, "Float", h)
				DllCall("gdiplus\GdipSetClipRegion", "UPtr", g, "UPtr", Region, "Int", 0)
				DllCall("gdiplus\GdipSetClipRect", "UPtr", g, "Float", x - (2 * r), "Float", y + r, "Float", w + (4 * r), "Float", h - (2 * r), "Int", 4)
				DllCall("gdiplus\GdipSetClipRect", "UPtr", g, "Float", x + r, "Float", y - (2 * r), "Float", w - (2 * r), "Float", h + (4 * r), "Int", 4)
				DllCall("gdiplus\GdipFillEllipse", "UPtr", g, "UPtr", b, "Float", x, "Float", y, "Float", 2 * r, "Float", 2 * r)
				DllCall("gdiplus\GdipFillEllipse", "UPtr", g, "UPtr", b, "Float", x + w - (2 * r), "Float", y, "Float", 2 * r, "Float", 2 * r)
				DllCall("gdiplus\GdipFillEllipse", "UPtr", g, "UPtr", b, "Float", x, "Float", y + h - (2 * r), "Float", 2 * r, "Float", 2 * r)
				DllCall("gdiplus\GdipFillEllipse", "UPtr", g, "UPtr", b, "Float", x + w - (2 * r), "Float", y + h - (2 * r), "Float", 2 * r, "Float", 2 * r)
				DllCall("gdiplus\GdipSetClipRegion", "UPtr", g, "UPtr", Region, "Int", 0)
				DllCall("gdiplus\GdipDeleteRegion", "UPtr", Region)
			}

			DrawRoundedRectangle(g, p, x, y, w, h, r) {
				DllCall("gdiplus\GdipSetClipRect", "UPtr", g, "Float", x - r, "Float", y - r, "Float", 2 * r, "Float", 2 * r, "Int", 4)
				DllCall("gdiplus\GdipSetClipRect", "UPtr", g, "Float", x + w - r, "Float", y - r, "Float", 2 * r, "Float", 2 * r, "Int", 4)
				DllCall("gdiplus\GdipSetClipRect", "UPtr", g, "Float", x - r, "Float", y + h - r, "Float", 2 * r, "Float", 2 * r, "Int", 4)
				DllCall("gdiplus\GdipSetClipRect", "UPtr", g, "Float", x + w - r, "Float", y + h - r, "Float", 2 * r, "Float", 2 * r, "Int", 4)
				DllCall("gdiplus\GdipDrawRectangle", "UPtr", g, "UPtr", p, "Float", x, "Float", y, "Float", w, "Float", h)
				DllCall("gdiplus\GdipResetClip", "UPtr", g)
				DllCall("gdiplus\GdipSetClipRect", "UPtr", g, "Float", x - (2 * r), "Float", y + r, "Float", w + (4 * r), "Float", h - (2 * r), "Int", 4)
				DllCall("gdiplus\GdipSetClipRect", "UPtr", g, "Float", x + r, "Float", y - (2 * r), "Float", w - (2 * r), "Float", h + (4 * r), "Int", 4)
				DllCall("gdiplus\GdipDrawEllipse", "UPtr", g, "UPtr", p, "Float", x, "Float", y, "Float", 2 * r, "Float", 2 * r)
				DllCall("gdiplus\GdipDrawEllipse", "UPtr", g, "UPtr", p, "Float", x + w - (2 * r), "Float", y, "Float", 2 * r, "Float", 2 * r)
				DllCall("gdiplus\GdipDrawEllipse", "UPtr", g, "UPtr", p, "Float", x, "Float", y + h - (2 * r), "Float", 2 * r, "Float", 2 * r)
				DllCall("gdiplus\GdipDrawEllipse", "UPtr", g, "UPtr", p, "Float", x + w - (2 * r), "Float", y + h - (2 * r), "Float", 2 * r, "Float", 2 * r)
				DllCall("gdiplus\GdipResetClip", "UPtr", g)
			}
		}
	}

	class Doughnut extends Charter.Pie {

		isDoughnut := true
	}

		class ChartRenderer extends Charter.Box {

		render(g) {
			this.prepare()

			chart := this.parent
			canvasRect := chart.contentRect
			this.rect := canvasRect
			this.borderColor := chart.borderColor
			this.borderLeft := chart.borderLeft
			this.borderTop := chart.borderTop
			this.borderRight := chart.borderRight
			this.borderBottom := chart.borderBottom

			DllCall("gdiplus\GdipCreateSolidFill", "UInt", this.argb(chart.backgroundColor), "UPtr*", brush)
			DllCall("gdiplus\GdipFillRectangle", "UPtr", g, "UPtr", brush, "Float", chart.x, "Float", chart.y, "Float", chart.width, "Float", chart.height)
			DllCall("gdiplus\GdipDeleteBrush", "UPtr", brush)

			if (chart.title.text != "")
				title := chart.title

			if (chart.xAxis.title.text != "")
				xTitle := chart.xAxis.title

			if (chart.yAxis.title.text != "")
				yTitle := chart.yAxis.title

			if (IsObject(chart.xAxis.labels) ? chart.xAxis.labels.length() : chart.xAxis.labels != "") {
				xLabels := chart.xAxis.labels
				if !(IsObject(xLabels))
					xLabels := StrSplit(xLabels, ",")
				this.xFormatter := ""
			}

			if (IsObject(chart.yAxis.labels) ? chart.yAxis.labels.length() : chart.yAxis.labels != "") {
				yLabels := chart.yAxis.labels
				if !(IsObject(yLabels))
					yLabels := StrSplit(yLabels, ",")
				this.yFormatter := ""
			}

			if (title) {
				if (title.font == "")
					title.font := chart.font
				if (title.color == "")
					title.color := chart.color
				title.rect := canvasRect
				title.height := 0
				title.height := title.measure(g).height + (title.height - title.contentRect.height)
				this.top += title.height
			}

			if (chart.xAxis.gridCount)
				xGridCount := chart.xAxis.gridCount - 1
			else if (xLabels)
				xGridCount := xLabels.count() - 1

			if (chart.yAxis.gridCount)
				yGridCount := chart.yAxis.gridCount - 1
			else if (yLabels)
				yGridCount := yLabels.count() - 1

			if (xGridCount && !xLabels) {
				xLabels := []
				loop % xGridCount + 1
					xLabels.push(this.min.x + (this.range.x / xGridCount) * (A_Index - 1))
			}
			if (yGridCount && !yLabels) {
				yLabels := []
				loop % yGridCount + 1
					yLabels.push(this.min.y + (this.range.y / yGridCount) * (A_Index - 1))
			}

			xFormatter := this.xFormatter
			yFormatter := this.yFormatter

			if (xLabels)
				this.count := xLabels.count()

			if (this.isHorizontal) {
				this._swap(xTitle, yTitle)
				this._swap(xLabels, yLabels)
				this._swap(xGridCount, yGridCount)
				this._swap(xFormatter, yFormatter)
				if (chart.type = "Bar" || chart.type = "BarH" || chart.type = "BarV")
					columnAxis := "y"
			} else {
				for i, v in tmp := yLabels, yLabels := []
					yLabels.insertAt(1, v)
				if (chart.type = "Bar" || chart.type = "BarH" || chart.type = "BarV")
					columnAxis := "x"
			}

			if (chart.type = "Pie" || chart.type = "Doughnut")
				xLabels := yLabels := xTitle := yTitle := xGridCount := yGridCount := ""

			if (yTitle) {
				if (yTitle.font == "")
					yTitle.font := chart.font
				if (yTitle.color == "")
					yTitle.color := chart.color
				rect := this.contentRect
				yTitle.x := -this.bottom
				yTitle.y := this.x
				yTitle.width := rect.height
				yTitle.height := this.width * 0.3
				yTitle.height := yTitle.measure(g).height + (yTitle.height - yTitle.contentRect.height)
				this.left += yTitle.height
			}

			if (yLabels.length()) {
				lr := yLabelRenderer := new Charter.AxisLabels(yLabels)
				lr.labelAlign := 1
				if (lr.label.font == "")
					lr.label.font := chart.font
				if (lr.label.color == "")
					lr.label.color := chart.color
				if (yFormatter)
					lr.formatter := yFormatter
				if (columnAxis == "y")
					lr.labelAlign := 0
				lr.rect := this.contentRect
				lr.label.align := "Right"
				lr.label.lineAlign := "Center"
				lr.paddingRight := 14
				lr.width *= 0.3
				lr.width := lr.measure(g).width + (lr.width - lr.contentRect.width)
				this.left += lr.width
			}

			if (this.datasetLabels) {
				this.datasetLabels.rect := this.contentRect
				size := this.datasetLabels.measure(g)
				this.top += size.height
				if (yTitle)
					yTitle.x := -this.bottom, yTitle.width := this.contentRect.height
				if (yLabelRenderer)
					yLabelRenderer.y += size.height
			}

			if (xTitle) {
				if (xTitle.font == "")
					xTitle.font := chart.font
				if (xTitle.color == "")
					xTitle.color := chart.color
				xTitle.rect := this.contentRect
				xTitle.height := xTitle.measure(g).height + (xTitle.height - xTitle.contentRect.height)
				this.bottom -= xTitle.height
				rect := this.contentRect
				xTitle.y := rect.y + rect.height
				if (yTitle) {
					yTitle.x := -this.bottom
					yTitle.width := rect.height
				}
				if (yLabelRenderer)
					yLabelRenderer.height := rect.height
			}

			if (xLabels.length()) {
				lr := xLabelRenderer := new Charter.AxisLabels(xLabels)
				lr.labelAlign := 1
				if (lr.label.font == "")
					lr.label.font := chart.font
				if (lr.label.color == "")
					lr.label.color := chart.color
				if (xFormatter)
					lr.formatter := xFormatter
				if (columnAxis == "x")
					lr.labelAlign := 0
				lr.rect := this.contentRect
				lr.isHorizontal := true
				lr.label.align := "Center"
				lr.marginTop := 8
				lr.height *= 0.3
				lr.height := lr.measure(g).height + (lr.height - lr.contentRect.height)
				this.bottom -= lr.height
				rect := this.contentRect
				lr.y := rect.y + rect.height
				if (yTitle) {
					yTitle.x := -this.bottom
					yTitle.width := rect.height
				}
				if (yLabelRenderer)
					yLabelRenderer.height := rect.height
			}

			if (columnAxis != "y" && yGridCount && (width := chart.yAxis.gridWidth)) {
				if ((color := chart.yAxis.gridColor) == "")
					color := chart.gridColor

				DllCall("gdiplus\GdipCreatePen1", "UInt", this.argb(color), "Float", width, "Int", 2, "UPtr*", pen)
				rect := this.contentRect
				loop % yGridCount + 1 {
					y := rect.y + (rect.height / yGridCount) * (A_Index - 1)
					DllCall("gdiplus\GdipDrawLine", "UPtr", g, "UPtr", pen, "Float", rect.x, "Float", y, "Float", rect.x + rect.width, "Float", y)
				}
				DllCall("gdiplus\GdipDeletePen", "UPtr", pen)
			}

			if (columnAxis != "x" && xGridCount && (width := chart.xAxis.gridWidth)) {
				if ((color := chart.xAxis.gridColor) == "")
					color := chart.gridColor

				DllCall("gdiplus\GdipCreatePen1", "UInt", this.argb(color), "Float", width, "Int", 2, "UPtr*", pen)
				rect := this.contentRect
				loop % xGridCount + 1 {
					x := rect.x + (rect.width / xGridCount) * (A_Index - 1)
					DllCall("gdiplus\GdipDrawLine", "UPtr", g, "UPtr", pen, "Float", x, "Float", rect.y, "Float", x, "Float", rect.y + rect.height)
				}
				DllCall("gdiplus\GdipDeletePen", "UPtr", pen)
			}

			this.drawBorder(g)
			this.drawChart(g)

			if (title)
				title.render(g)
			if (this.datasetLabels)
				this.datasetLabels.render(g)
			if (yLabelRenderer)
				yLabelRenderer.render(g)
			if (xLabelRenderer)
				xLabelRenderer.render(g)
			if (yTitle) {
				DllCall("gdiplus\GdipRotateWorldTransform", "UPtr", g, "Float", -90, "Int", 0)
				yTitle.render(g)
				DllCall("gdiplus\GdipResetWorldTransform", "UPtr", g)
			}
			if (xTitle)
				xTitle.render(g)
		}

		prepare() {
			chart := this.parent
			min := []
			max := []
			labels := chart.labels
			if !(IsObject(labels))
				labels := StrSplit(labels, ",")
			labeleds := []
			this.count := 0

			for i, dataset in chart.datasets {
				if (dataset.color == "")
					dataset.color := chart._color()
				if (dataset.label != "")
					labeleds.push({label:dataset.label, color:dataset.color})
				else if (labels[i])
					labeleds.push({label:labels[i], color:dataset.color})

				this.count := Max(this.count, dataset.data.count())

				switch (chart.type) {
					case "Bar", "BarV", "BarH", "Line", "Pie", "Doughnut":
						if (A_Index == 1) {
							for i, v in dataset.data {
								if (IsObject(v)) {
									if (dataset.yKey == "")
										dataset.yKey := 2
									keys := StrSplit(dataset.yKey, ".")
								}
								min.y := max.y := keys ? v[keys*] : v
								break
							}
						}
						if (keys)
							for i, v in dataset.data {
								v := v[keys*]
								min.y := Min(min.y, v)
								max.y := Max(max.y, v)
							}
						else
							for i, v in dataset.data {
								min.y := Min(min.y, v)
								max.y := Max(max.y, v)
							}
					case "Scatter", "Bubble":
						xKeys := dataset.xKey == "" ? [1] : StrSplit(dataset.xKey, ".")
						yKeys := dataset.yKey == "" ? [2] : StrSplit(dataset.yKey, ".")
						rKeys := dataset.rKey == "" ? [3] : StrSplit(dataset.rKey, ".")
						if (A_Index == 1) {
							for i, v in dataset.data {
								min.x := max.x := v[xKeys*]
								min.y := max.y := v[yKeys*]
								min.r := max.r := v[rKeys*]
								break
							}
						}
						for i, v in dataset.data {
							x := v[xKeys*], y := v[yKeys*], r := v[rKeys*]
							min.x := Min(min.x, x), max.x := Max(max.x, x)
							min.y := Min(min.y, y), max.y := Max(max.y, y)
							min.r := Min(min.r, r), max.r := Max(max.r, r)
						}
				}
			}

			if (chart.type != "Pie" && chart.type != "Doughnut" && labeleds) {
				this.datasetLabels := new Charter.DatasetLabelRenderer(labeleds, chart.font)
				this.datasetLabels.parent := this
			}

			if (chart.xAxis.formatter)
				this.xFormatter := IsObject(chart.xAxis.formatter) ? chart.xAxis.formatter : Func(chart.xAxis.formatter)
			else if (chart.xAxis.format != "")
				this.xFormatter := Func("Format").bind(chart.xAxis.format)
			else
				this.xFormatter := this._is(min.x, "Float") || this._is(max.x, "Float") ? this._returnSelf : Func("Round")

			if (chart.yAxis.formatter)
				this.yFormatter := IsObject(chart.yAxis.formatter) ? chart.yAxis.formatter : Func(chart.yAxis.formatter)
			else if (chart.yAxis.format != "")
				this.yFormatter := Func("Format").bind(chart.yAxis.format)
			else
				this.yFormatter := this._is(min.y, "Float") || this._is(max.y, "Float") ? this._returnSelf : Func("Round")

			r := (r := max.x - min.x) ? r : .1, max.x += r * 0.2, min.x -= r * 0.2
			r := (r := max.y - min.y) ? r : .1, max.y += r * 0.2, min.y -= r * 0.2
			r := (r := max.r - min.r) ? r : .1, max.r += r * 0.2, min.r -= r * 0.2

			if (chart.xAxis.min != "")
				min.x := chart.xAxis.min
			if (chart.xAxis.max != "")
				max.x := chart.xAxis.max
			if (chart.yAxis.min != "")
				min.y := chart.yAxis.min
			if (chart.yAxis.max != "")
				max.y := chart.yAxis.max

			this.range := {x:max.x-min.x, y:max.y-min.y, r:max.r-min.r}
			this.min := min
			this.max := max
		}

		_is(var, type) {
			if var is %type%
				return true
		}

		_swap(byref a, byref b) {
			t := a, a := b, b := t
		}

		_returnSelf() {
			return this
		}
	}

	class DatasetLabelRenderer extends Charter.Box {

		iconWidth := 10

		__new(datasets, font) {
			this.datasets := datasets
			this.tr := new Charter.TextRenderer
			this.tr.font := font
			this.tr.align := "Center"
			this.tr.lineAlign := "Center"
			this.tr.width := rect.width
		}

		measure(g) {
			rect := this.contentRect
			this.tr.rect := rect
			padding := 6

			this.rows := [row := []]
			this.widths := []
			offset := 0
			lineHeight := 0
			for i, dataset in this.datasets {
				rc := this.tr.measure(g, dataset.label)
				width := rc.width + this.iconWidth + padding * 2
				height := rc.height + padding * 2
				offset += width
				item := {label:dataset.label, color:dataset.color, textW:rc.width, width:width, height:height}
				if (offset > rect.width) {
					offset := width
					this.rows.push(row := [item])
				} else {
					row.push(item)
				}
				this.widths[this.rows.length()] := offset
			}

			maxW := maxH := 0
			for i, row in this.rows {
				rowW := 0
				rowH := 0
				for j, item in row {
					rowW += item.width
					rowH := Max(rowH, item.height)
				}
				maxW := Max(maxW, rowW)
				maxH += rowH
			}
			return {width:maxW, height:maxH}
		}

		render(g) {
			if !(this.rows)
				this.measure(g)
			rect := this.contentRect
			this.tr.color := this.parent.parent.color
			y := this.rect.y
			padding := 6
			for i, row in this.rows {
				rowW := 0
				rowH := 0
				for j, item in row {
					rowW += item.width
					rowH := Max(rowH, item.height)
				}

				offset := 0
				for j, item in row {
					x := rect.x + rect.width / 2 - rowW / 2 + offset
					this.tr.x := x + this.iconWidth + padding
					this.tr.y := y
					this.tr.width := item.textW
					this.tr.height := item.height
					this.tr.render(g, item.label)

					DllCall("gdiplus\GdipCreateSolidFill", "UInt", this.argb(item.color), "UPtr*", brush)
					DllCall("gdiplus\GdipFillEllipse", "UPtr", g, "UPtr", brush, "Float", x, "Float", y + item.height / 2 - this.iconWidth / 2 - 1, "Float", this.iconWidth, "Float", this.iconWidth)
					DllCall("gdiplus\GdipDeleteBrush", "UPtr", brush)

					offset += item.width
				}
				y += rowH
			}
		}
	}

	class AxisLabels extends Charter.Box {

		labelAlign := 0

		__new(labels, args*) {
			this.labels := labels
			this.label := new Charter.TextRenderer(args*)
		}

		measure(g) {
			rect := this.contentRect
			if (this.isHorizontal) {
				width := rect.width
				height := 0
				this.label.width := rect.width / this.labels.count()
				this.label.height := rect.height
			} else {
				width := 0
				height := rect.height
				this.label.width := rect.width
				this.label.height := rect.height / this.labels.count()
			}
			for i, label in this.labels {
				size := this.label.measure(g, this.formatter.call(label))
				width := Max(width, size.width)
				height := Max(height, size.height)
			}
			return {width:width, height:height}
		}

		render(g) {
			rect := this.contentRect
			label := this.label
			label.x := rect.x
			label.y := rect.y
			count := this.labels.count()
			if (this.isHorizontal) {
				if (this.labelAlign == 0) {
					partWidth := rect.width / count
					label.width := partWidth
					label.height := rect.height
					for i, v in this.labels {
						label.x := rect.x + partWidth * (A_Index - 1)
						label.render(g, this.formatter.call(v))
					}
				} else {
					partWidth := rect.width / Max(1, count - 1)
					label.width := partWidth
					label.height := rect.height
					for i, v in this.labels {
						if (A_Index == 1) {
							label.align := 0
							label.x := rect.x + partWidth * (A_Index - 1)
						} else if (A_Index == count) {
							label.align := 2
							label.x := rect.x + rect.width - partWidth
						} else {
							label.align := 1
							label.x := rect.x + partWidth * (A_Index - 1) - partWidth / 2
						}
						label.render(g, this.formatter.call(v))
					}
				}
			} else {
				if (this.labelAlign == 0) {
					partHeight := rect.height / count
					label.width := rect.width
					label.height := partHeight
					for i, v in this.labels {
						label.y := rect.y + partHeight * (A_Index - 1)
						label.render(g, this.formatter.call(v))
					}
				} else {
					partHeight := rect.height / Max(1, count - 1)
					label.width := rect.width
					label.height := partHeight
					for i, v in this.labels {
						if (A_Index == 1) {
							label.lineAlign := 0
							label.y := rect.y + partHeight * (A_Index - 1)
						} else if (A_Index == count) {
							label.lineAlign := 2
							label.y := rect.y + rect.height - partHeight
						} else {
							label.lineAlign := 1
							label.y := rect.y + partHeight * (A_Index - 1) - partHeight / 2
						}
						label.render(g, this.formatter.call(v))
					}
				}
			}
		}

		formatter() {
			return this
		}
	}

	class TextRenderer extends Charter.Box {

		_align := 0

		_lineAlign := 0

		font := ""

		fontSize := 12

		__new(options := "", font := "") {
			this.options := options
			this.font := font
		}

		__delete() {
			if (this.pBrush)
				DllCall("gdiplus\GdipDeleteBrush", "UPtr", this.delete("pBrush"))
			if (this.hFormat)
				DllCall("gdiplus\GdipDeleteStringFormat", "UPtr", this.delete("hFormat"))
			if (this.hFont)
				DllCall("gdiplus\GdipDeleteFont", "UPtr", this.delete("hFont"))
			if (this.hFamily)
				DllCall("gdiplus\GdipDeleteFontFamily", "UPtr", this.delete("hFamily"))
		}

		_parseOptions() {
			if (this.hFamily)
				return

			fontSize := this.fontSize
			color := this._color
			align := this._align
			lineAlign := this._lineAlign

			DllCall("gdiplus\GdipCreateFontFamilyFromName", "UPtr", &font := this.font, "UInt", 0, "UPtr*", hFamily)
			if !(this.hFamily := hFamily)
				throw Exception("CreateFontFamily: " this.font)

			style := 0
			loop parse, % Trim(RegExReplace(this.options, "\s+", " ")), % " "
				switch (a_loopField) {
					case "Left": align := 0
					case "Center": align := 1
					case "Right": align := 2
					case "Top": lineAlign := 0
					case "Middle", "vCenter": lineAlign := 1
					case "Bottom": lineAlign := 2
					case "Regular": style |= 0
					case "Bold": style |= 1
					case "Italic": style |= 2
					case "Underline": style |= 4
					case "Strikeout": style |= 8
					case "NoWrap": nowrap := true
					default:
						if (RegExMatch(a_loopField, "^[cC]([a-fA-F\d]+)$", m))
							color := "0x" m1
						else if (RegExMatch(a_loopField, "^[sS](\d+)$", m))
							fontSize := m1
						else if (RegExMatch(a_loopField, "^([xywhXYWH])(\d+)$", m))
							this[m1 = "w" ? "width" : m1 = "h" ? "height" : m1] := m2
						else
							throw Exception("invalid option: " a_loopField)
				}

			DllCall("gdiplus\GdipCreateFont", "UPtr", this.hFamily, "Float", fontSize, "Int", Style, "Int", 0, "UPtr*", hFont)
			if !(this.hFont := hFont)
				throw Exception("FontCreate")
			DllCall("gdiplus\GdipCreateStringFormat", "Int", nowrap ? 0x4000 | 0x1000 : 0x4000, "Int", 0, "UPtr*", hFormat)
			if !(this.hFormat := hFormat)
				throw Exception("StringFormatCreate")

			this.color := color
			this.align := align
			this.lineAlign := lineAlign
		}

		measure(g, text := "") {
			this._parseOptions()
			rect := this.contentRect
			VarSetCapacity(rc, 16)
			NumPut(rect.x, rc, 0, "Float"), NumPut(rect.y, rc, 4, "Float"), NumPut(rect.width, rc, 8, "Float"), NumPut(rect.height, rc, 12, "Float")
			VarSetCapacity(outrc, 16)
			DllCall("gdiplus\GdipMeasureString", "UPtr",  g
			                                   , "WStr",  text == "" ? this.text : text
			                                   , "Int",   -1
			                                   , "UPtr",  this.hFont
			                                   , "UPtr",  &rc
			                                   , "UPtr",  this.hFormat
			                                   , "UPtr",  &outrc
			                                   , "UInt*", chars
			                                   , "UInt*", lines)
			return {lines:lines, chars:chars
				, x:NumGet(outrc, 0, "Float"), y:NumGet(outrc, 4, "Float")
				, width:NumGet(outrc, 8, "Float"), height:NumGet(outrc, 12, "Float")}
		}

		render(g, text := "") {
			this._parseOptions()
			rect := this.contentRect
			VarSetCapacity(rc, 16)
			NumPut(rect.x, rc, 0, "Float"), NumPut(rect.y, rc, 4, "Float"), NumPut(rect.width, rc, 8, "Float"), NumPut(rect.height, rc, 12, "Float")
			DllCall("gdiplus\GdipDrawString", "UPtr", g
			                                , "WStr", text == "" ? this.text : text
			                                , "Int",  -1
			                                , "UPtr", this.hFont
			                                , "UPtr", &rc
			                                , "UPtr", this.hFormat
			                                , "UPtr", this.pBrush)
			this.debugFrame(g)
		}

		color[] {
			get {
				return this._color
			}
			set {
				this._color := this.argb(value == "" ? 0 : value)
				if (this.pBrush)
					DllCall("gdiplus\GdipSetSolidFillColor", "UPtr", this.pBrush, "UInt", this._color)
				else
					DllCall("gdiplus\GdipCreateSolidFill", "UInt", this._color, "UPtr*", pBrush), this.pBrush := pBrush
				return value
			}
		}

		align[] {
			get {
				return this._align
			}
			set {
				static map := {"":0, 0:0, 1:1, 2:2, Left:0, Center:1, Right:2, Near:0, Far:2}
				return this._align := value
					, DllCall("gdiplus\GdipSetStringFormatAlign", "UPtr", this.hFormat, "Int", map[value])
			}
		}

		lineAlign[] {
			get {
				return this._lineAlign
			}
			set {
				static map := {"":0, 0:0, 1:1, 2:2, Top:0, Center:1, Middle:1, Bottom:2, Near:0, Far:2}
				return this._lineAlign := value
					, DllCall("gdiplus\GdipSetStringFormatLineAlign", "UPtr", this.hFormat, "Int", map[value])
			}
		}
	}


	class Box {

		static margin := Charter.Box._borderSetter.bind("margin")
		static border := Charter.Box._borderSetter.bind("border")
		static padding := Charter.Box._borderSetter.bind("padding")

		x := 0
		y := 0
		width := 0
		height := 0

		marginTop := 0
		marginRight := 0
		marginBottom := 0
		marginLeft := 0

		borderColor := 0xE2E2E2
		borderTop := 0
		borderRight := 0
		borderBottom := 0
		borderLeft := 0

		paddingTop := 0
		paddingRight := 0
		paddingBottom := 0
		paddingLeft := 0

		_borderSetter(self, args*) {
			switch (args.length()) {
				case 1:
					self[this "Top"] := args[1]
					self[this "Right"] := args[1]
					self[this "Bottom"] := args[1]
					self[this "Left"] := args[1]
				case 2:
					self[this "Top"] := args[1]
					self[this "Right"] := args[2]
					self[this "Bottom"] := args[1]
					self[this "Left"] := args[2]
				case 3:
					self[this "Top"] := args[1]
					self[this "Right"] := args[2]
					self[this "Bottom"] := args[3]
					self[this "Left"] := args[2]
				case 4:
					self[this "Top"] := args[1]
					self[this "Right"] := args[2]
					self[this "Bottom"] := args[3]
					self[this "Left"] := args[4]
				default:
					throw Exception("invalid " this " arguments")
			}
			return self
		}

		argb(color) {
			return color < 0x1000000 ? color | 0xFF000000 : color
		}

		debugFrame(g) {
			if !(Charter.debugmode)
				return
			color := this.borderColor
			borderTop := this.borderTop
			borderRight := this.borderRight
			borderBottom := this.borderBottom
			borderLeft := this.borderLeft
			this.borderColor := 0xA0FF0000
			this.border(1)
			this.drawBorder(g)
			this.borderColor := color
			this.borderTop := borderTop
			this.borderRight := borderRight
			this.borderBottom := borderBottom
			this.borderLeft := borderLeft
		}

		drawBorder(g) {
			DllCall("gdiplus\GdipCreatePen1", "UInt", this.argb(this.borderColor), "Float", 1, "Int", 2, "UPtr*", pen)
			if (this.borderTop) {
                w := this.borderTop / 2
                DllCall("gdiplus\GdipSetPenWidth", "UPtr", pen, "Float", this.borderTop)
				DllCall("gdiplus\GdipDrawLine", "UPtr", g, "UPtr", pen
											  , "Float", this.x + this.marginLeft
											  , "Float", this.y + this.marginTop + w
											  , "Float", this.right - this.marginRight
											  , "Float", this.y + this.marginTop + w)
            }
            if (this.borderRight) {
                w := this.borderRight / 2
                DllCall("gdiplus\GdipSetPenWidth", "UPtr", pen, "Float", this.borderRight)
				DllCall("gdiplus\GdipDrawLine", "UPtr", g, "UPtr", pen
											  , "Float", this.right - this.marginRight - w
											  , "Float", this.y + this.marginTop
											  , "Float", this.right - this.marginRight - w
											  , "Float", this.bottom - this.marginBottom)
            }
            if (this.borderBottom) {
                w := this.borderBottom / 2
                DllCall("gdiplus\GdipSetPenWidth", "UPtr", pen, "Float", this.borderBottom)
				DllCall("gdiplus\GdipDrawLine", "UPtr", g, "UPtr", pen
											  , "Float", this.x + this.marginLeft
											  , "Float", this.bottom - this.marginBottom - w
											  , "Float", this.right - this.marginRight
											  , "Float", this.bottom - this.marginBottom - w)
            }
            if (this.borderLeft) {
                w := this.borderLeft / 2
                DllCall("gdiplus\GdipSetPenWidth", "UPtr", pen, "Float", this.borderLeft)
				DllCall("gdiplus\GdipDrawLine", "UPtr", g, "UPtr", pen
											  , "Float", this.x + this.marginLeft + w
											  , "Float", this.y + this.marginTop
											  , "Float", this.x + this.marginLeft + w
											  , "Float", this.bottom - this.marginBottom)
			}
			DllCall("gdiplus\GdipDeletePen", "UPtr", pen)
			return this
		}

		parent[] {
			get {
				if (this._parent)
					return Object(this._parent)
			}
			set {
				return value, this._parent := &value
			}
		}

		rect[] {
			get {
				return {x:this.x, y:this.y, width:this.width, height:this.height}
			}
			set {
				return value, this.x := value.x, this.y := value.y, this.width := value.width, this.height := value.height
			}
		}

		contentRect[] {
			get {
				x := this.marginLeft + this.borderLeft + this.paddingLeft
				y := this.marginTop + this.borderTop + this.paddingTop
				w := this.width - x - this.marginRight - this.borderRight - this.paddingRight
				h := this.height - y - this.marginBottom - this.borderBottom - this.paddingBottom
				return {x:this.x + x, y:this.y + y, width:w, height:h}
			}
		}

		top[] {
			get {
				return this.y
			}
			set {
				return value, this.height := this.y + this.height - value, this.y := value
			}
		}

		right[] {
			get {
				return this.x+this.width
			}
			set {
				return value, this.width := value-this.x
			}
		}

		bottom[] {
			get {
				return this.y+this.height
			}
			set {
				return value, this.height := value-this.y
			}
		}

		left[] {
			get {
				return this.x
			}
			set {
				return value, this.width := this.x+this.width-value, this.x := value
			}
		}
	}
}

ChartGuiClose(hwnd) {
	Gui % hwnd ":Destroy"
}


UseGDIP(Params*) { ; Loads and initializes the Gdiplus.dll at load-time
	static GdipObject := ""
		 , GdipModule := ""
		 , GdipToken  := ""
	static OnLoad := UseGDIP()
	if (GdipModule = "") {
		if !(DllCall("LoadLibrary", "Str", "Gdiplus.dll", "UPtr"))
			UseGDIP_Error("The Gdiplus.dll could not be loaded!`n`nThe program will exit!")
		if !(DllCall("GetModuleHandleEx", "UInt", 0x00000001, "Str", "Gdiplus.dll", "Ptr*", GdipModule, "UInt"))
			UseGDIP_Error("The Gdiplus.dll could not be loaded!`n`nThe program will exit!")
		VarSetCapacity(SI, 24, 0), NumPut(1, SI, 0, "UInt")
		if (DllCall("gdiplus\GdiplusStartup", "Ptr*", GdipToken, "Ptr", &SI, "Ptr", 0))
			UseGDIP_Error("GDI+ could not be startet!`n`nThe program will exit!")
		GdipObject := {Base: {__Delete: Func("UseGDIP").Bind(GdipModule, GdipToken)}}
	}
	else if (Params[1] = GdipModule) && (Params[2] = GdipToken)
		DllCall("gdiplus\GdiplusShutdown", "Ptr", GdipToken)
}

UseGDIP_Error(ErrorMsg) {
	MsgBox, 262160, UseGDIP, %ErrorMsg%
	ExitApp
}