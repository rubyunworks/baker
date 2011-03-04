# Baker - The Delicious Program Maker
# (c)2003 The Baker Project, LGPL

# Baker is free software; you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# Baker is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with Baker; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA

#
# Baker's Error Classes
# yes, they get used a lot ;)
#
module Baker

  class BakerError < StandardError
  end

  class DependencyError < BakerError
  end

  class ConflictError < BakerError
  end

end
