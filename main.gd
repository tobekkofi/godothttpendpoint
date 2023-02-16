#Code originally chopped from https://github.com/KOBUGE-Games/godot-httpd
#HTTP server for requests
#Still a work in progress but provides a starting point.


extends Node2D


var srv = TCPServer.new()

func _ready():
	var port = 40004
	srv.listen(port)
	print(str("Server listening at http://localhost:", port))

func _process(delta):
	var incon = srv.take_connection()
	if incon != null:
		run_srvr(incon)


func run_srvr(incn):
	var con = incn
	var req = parse_request(con)
	if (typeof(req) == TYPE_ARRAY):
		var mth = req[0]
		var path = req[1]
		if (mth == "GET"):
			write_file(con)
		elif (mth == "POST"):
			check_path(path, con)
		else:
			write_error(con, "501 Not Implemented", str("HTTP method '", mth, "' not supported!"))

	con.disconnect_from_host()

func check_path(path, con):
	#Use regex to check path for values of param1, param2 and param3
	var regex = RegEx.new()
	regex.compile(("^(?=.*param1=([^&]+)|)(?=.*param2=([^&]+)|)(?=.*param3=([^&]+)|).+$"))
	var results = regex.search(path) #process path through regex
	#param1 will be array entry one, param2 entry 2 etc etc. Perform whatever actions needed in here.
	if (results.get_string(1) != ""):
		print("param 1 is " + results.get_string(1))
	elif (results.get_string(2) != ""):
		print("param 2 is " + results.get_string(2))
	elif (results.get_string(3) != ""):
		print("param 3 is " + results.get_string(3))
	else:
		write_error(con, "400 Bad Request", str("Path ", path, "contains no valid parameters"))
	
	
	write_file(con)

func write_str(con, stri): #write out the string to connecting client
	return con.put_data(PackedByteArray(stri.to_utf8_buffer()))

# decodes the percent encoding in urls
func decode_percent_url(url):
	var arr = url.split("%")
	var first = true
	var in_seq = false
	var encod_seq
	var ret = arr[0]
	#print(str("URL: ", url))
	for stri in arr:
		if (not first):
			var hex = stri.substr(0, 2)
			var hi = str("0x", hex).hex_to_int()

			if (in_seq):
				encod_seq.push_back(hi)
			if (stri.length() == 2):
				if (in_seq == false):
					in_seq = true
					encod_seq = [hi]
			else:
				if (in_seq):
					in_seq = false
					var encoded = PackedByteArray(encod_seq).get_string_from_utf8()
					ret = str(ret, encoded, stri.substr(2, stri.length()))
		else:
			first = false

	#the url can end with a percent encoded part
	if (in_seq):
		var encoded = PackedByteArray(encod_seq).get_string_from_utf8()
		ret = str(ret, encoded)
	return ret

# reads (and blocks) until the first \n, and perhaps more.
# you can feed the "more" part to the startstr arg
# of subsequent calls
func read_line(con, startstr):
	var first = true
	var pdata
	var pdatastr
	var retstr = startstr
	if (startstr.find("\n") != -1):
		return startstr
	while (first or (pdatastr.find("\n") == -1)):
		first = false
		pdata = con.get_partial_data(64)
		if (pdata[0] != OK):
			return false
		if (pdata[1].size() != 0):
			pdatastr = pdata[1].get_string_from_ascii()
		else:
			pdata = con.get_data(8) # force block
			if (pdata[0] != OK):
				return false
			pdatastr = pdata[1].get_string_from_ascii()
		retstr = str(retstr, pdatastr)
	return retstr


func write_error(con, error, content):
	var cont_data = content.to_utf8_buffer()
	write_str(con, str("HTTP/1.0 ", error, "\n"))
	write_str(con, str("Content-Length: ", cont_data.size(), "\n"))
	write_str(con, "Connection: close\n")
	write_str(con, "\n")
	con.put_data(cont_data)


#does not actually write file, just uses write_str
func write_file(con):
	#var f = FileAccess.new()
	#print(str("Sending file ", path, " to ", con.get_connected_host()))
	write_str(con, "HTTP/1.0 200 OK\n")
	write_str(con, "Connection: close\n")
	write_str(con, "\n")
#	var buf
#	var first = true
#	var sum = 0
#	#f.close()



# returns the path and method if no error, sends error and false if error
func parse_request(con):
	var st_line = read_line(con, "")
	#if (not st_line):
	#	write_error(con, "500 Server error", "Error while reading.")
	#	return false
	var lines = st_line.split("\n")
	var arr = lines[0].split(" ")
	#if (arr.size() != 3):
	#	write_error(con, "400 Forbidden", "Invalid request!")
	#	return false
	var mth = arr[0]
	var url = decode_percent_url(arr[1])
	#if ((url.find("\\") != -1) or (url.find("../") != -1)):
	#	write_error(con, "403 Forbidden", "Forbidden URL!")
	#	return false
	#else:
	#	return [mth, url]
	return [mth, url]
