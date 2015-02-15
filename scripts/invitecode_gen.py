import uuid

u = ""
s = "INSERT INTO member (invite_code) VALUES ('%s');"

for i in xrange(50):
    v = uuid.uuid4()
    print s % v
    u += str(v) + "\n"

print u
